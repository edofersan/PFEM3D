#include <cassert>
#include <chrono>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <limits>

#if defined(_OPENMP)
    #include <cstdlib>
    #include <omp.h>
#endif

#include <gmsh.h>
#include <nlohmann/json.hpp>

#include "SolverCompressible.hpp"
#include "../quadrature/gausslegendre.hpp"


SolverCompressible::SolverCompressible(const nlohmann::json& j, std::string mshName, std::string resultsName) :
m_mesh(j)
{
    m_verboseOutput             = j["verboseOutput"].get<bool>();

    m_p.hchar                   = j["Remeshing"]["hchar"].get<double>();

    m_p.gravity                 = j["Solver"]["gravity"].get<double>();

    m_p.fluid.rho0              = j["Solver"]["Fluid"]["rho0"].get<double>();
    m_p.fluid.mu                = j["Solver"]["Fluid"]["mu"].get<double>();
    m_p.fluid.K0                = j["Solver"]["Fluid"]["K0"].get<double>();
    m_p.fluid.K0prime           = j["Solver"]["Fluid"]["K0prime"].get<double>();
    m_p.fluid.pInfty            = j["Solver"]["Fluid"]["pInfty"].get<double>();

    m_p.time.adaptDT            = j["Solver"]["Time"]["adaptDT"].get<bool>();
    m_p.time.securityCoeff      = j["Solver"]["Time"]["securityCoeff"].get<double>();
    m_p.time.maxDT              = j["Solver"]["Time"]["maxDT"].get<double>();
    m_p.time.simuTime           = j["Solver"]["Time"]["simuTime"].get<double>();
    m_p.time.simuDTToWrite      = j["Solver"]["Time"]["simuDTToWrite"].get<double>();
    m_p.time.currentDT          = m_p.time.maxDT;
    m_p.time.nextWriteTrigger   = m_p.time.simuDTToWrite;
    m_p.time.currentTime        = 0.0;
    m_p.time.currentStep        = 0;

    m_p.initialCondition        = j["Solver"]["initialCondition"].get<std::vector<double>>();

    // set the desired number of OpenMP threads
#if defined(_OPENMP)
    const char* pNumThreads = std::getenv("OMP_NUM_THREADS");

    if(pNumThreads == nullptr)
        m_p.nOMPThreads = 1;
    else
        m_p.nOMPThreads = std::atoi(pNumThreads);

    omp_set_num_threads(m_p.nOMPThreads);
    Eigen::setNbThreads(m_p.nOMPThreads);
#else
     m_p.nOMPThreads = 1;
#endif

    m_mesh.loadFromFile(mshName);

    std::vector<std::string> whatToWrite = j["Solver"]["whatToWrite"];
    for(auto what : whatToWrite)
    {
        if(what == "u")
            m_p.whatToWrite[0] = true;
        else if(what == "v")
            m_p.whatToWrite[1] = true;
        else if(what == "p")
            m_p.whatToWrite[2] = true;
        else if(what == "ke")
            m_p.whatToWrite[3] = true;
        else if(what == "velocity")
            m_p.whatToWrite[4] = true;
        else if(what == "rho")
            m_p.whatToWrite[5] = true;
        else
            throw std::runtime_error("Unknown quantity to write!");
    }

    m_p.writeAs = j["Solver"]["writeAs"];
    if(!(m_p.writeAs == "Nodes" || m_p.writeAs == "Elements" || m_p.writeAs == "NodesElements"))
        throw std::runtime_error("Unexpected date type to write!");

    gmsh::initialize();

#ifndef NDEBUG
    gmsh::option::setNumber("General.Terminal", 1);
#else
    gmsh::option::setNumber("General.Terminal", 0);
#endif // DEBUG

    gmsh::option::setNumber("General.NumThreads", m_p.nOMPThreads);

    m_p.resultsName = resultsName;

    m_N = getN();

    m_sumNTN.resize(3,3); m_sumNTN.setZero();
    for(unsigned short k = 0 ; k < m_N.size() ; ++k)
        m_sumNTN += (m_N[k].topLeftCorner(1,3)).transpose()*m_N[k].topLeftCorner(1,3)*GP2Dweight<double>[k];

    m_m.resize(3);
    m_m << 1, 1, 0;

    m_ddev.resize(3, 3);
    m_ddev << 4.0/3, -2.0/3, 0,
             -2.0/3,  4.0/3, 0,
                  0,      0, 1;

    m_ddev *= m_p.fluid.mu;
}

SolverCompressible::~SolverCompressible()
{
    gmsh::finalize();
}

void SolverCompressible::applyBoundaryConditionsMom()
{
    assert(m_mesh.getNodesNumber() != 0);

    //Do not parallelize this
    for (std::size_t n = 0 ; n < m_mesh.getNodesNumber() ; ++n)
    {
        if(m_mesh.isNodeBound(n) || m_mesh.isNodeFree(n))
        {
            m_F(n) = 0;
            m_invM.diagonal()[n] = 1;

            m_F(n + m_mesh.getNodesNumber()) = 0;
            m_invM.diagonal()[n+m_mesh.getNodesNumber()] = 1;
        }
    }
}

void SolverCompressible::applyBoundaryConditionsCont()
{
    assert(m_mesh.getNodesNumber() != 0);

    //Do not parallelize this
    for (std::size_t n = 0 ; n < m_mesh.getNodesNumber() ; ++n)
    {
        if(m_mesh.isNodeFree(n))
        {
           m_Frho(n) = m_mesh.getNodeState(n, 3);

           m_invMrho.diagonal()[n] = 1;
        }
    }
}

void SolverCompressible::displaySolverParams() const
{
    std::cout << "Eigen sparse solver: SparseLU" << std::endl;
#if defined(_OPENMP)
    std::cout << "Number of OpenMP threads: " << m_p.nOMPThreads << std::endl;
#endif
    std::cout << "Gravity: " << m_p.gravity << " m/s^2" << std::endl;
    std::cout << "Density: " << m_p.fluid.rho0 << " kg/m^3" << std::endl;
    std::cout << "Viscosity: " << m_p.fluid.mu << " Pa s" << std::endl;
    std::cout << "K0: " << m_p.fluid.K0 << std::endl;
    std::cout << "K0prime: " << m_p.fluid.K0prime << std::endl;
    std::cout << "pInfty: " << m_p.fluid.pInfty << std::endl;
    std::cout << "End simulation time: " << m_p.time.simuTime << " s" << std::endl;
    std::cout << "Write solution every: " << m_p.time.simuDTToWrite << " s" << std::endl;
    std::cout << "Adapt time step: " << (m_p.time.adaptDT ? "yes" : "no") << std::endl;
    if(m_p.time.adaptDT)
    {
        std::cout << "Maximum time step: " << m_p.time.maxDT << " s" << std::endl;
        std::cout << "Security coefficient: " << m_p.time.securityCoeff << std::endl;
    }
    else
        std::cout << "Time step: " << m_p.time.maxDT << " s" << std::endl;
}

void SolverCompressible::setInitialCondition()
{
    assert(m_mesh.getNodesNumber() != 0);

    m_mesh.setStatesNumber(6);

    #pragma omp parallel for default(shared)
    for(std::size_t n = 0 ; n < m_mesh.getNodesNumber() ; ++n)
    {
        if(!m_mesh.isNodeBound(n) || m_mesh.isNodeFluidInput(n))
        {
            m_mesh.setNodeState(n, 0, m_p.initialCondition[0]);
            m_mesh.setNodeState(n, 1, m_p.initialCondition[1]);
            m_mesh.setNodeState(n, 2, m_p.initialCondition[2]);
        }
        else
        {
            m_mesh.setNodeState(n, 0, 0);
            m_mesh.setNodeState(n, 1, 0);
            m_mesh.setNodeState(n, 2, 0);
        }

        if(m_mesh.isNodeFree(n))
            m_mesh.setNodeState(n, 3, 0);
        else
            m_mesh.setNodeState(n, 3, m_p.initialCondition[3]);

        m_mesh.setNodeState(n, 4, 0);
        m_mesh.setNodeState(n, 5, 0);
    }

    m_qVPrev = getQFromNodesStates(0, 1);
    m_qAccPrev = getQFromNodesStates(4, 5);
}

void SolverCompressible::setNodesStatesfromQ(const Eigen::VectorXd& q, unsigned short beginState, unsigned short endState)
{
    assert (q.rows() == (endState - beginState + 1)*m_mesh.getNodesNumber());

    #pragma omp parallel for default(shared)
    for(std::size_t n = 0 ; n < m_mesh.getNodesNumber() ; ++n)
    {
        for (unsigned short s = beginState ; s <= endState ; ++s)
            m_mesh.setNodeState(n, s, q((s - beginState)*m_mesh.getNodesNumber() + n));
    }
}

void SolverCompressible::solveProblem()
{
    std::cout   << "================================================================"
                << std::endl
                << "                     EXECUTING THE SOLVER                       "
                << std::endl
                << "================================================================"
                << std::endl;

    displaySolverParams();

    std::cout << "----------------------------------------------------------------" << std::endl;

    setInitialCondition();

    writeData();

    while(m_p.time.currentTime < m_p.time.simuTime)
    {
        if(m_verboseOutput)
        {
            std::cout << "----------------------------------------------------------------" << std::endl;
            std::cout << "Solving time step: " << m_p.time.currentTime + m_p.time.currentDT
                      << "/" << m_p.time.simuTime << " s, dt = " << m_p.time.currentDT << std::endl;
            std::cout << "----------------------------------------------------------------" << std::endl;
        }
        else
        {
            std::cout << std::fixed << std::setprecision(3);
            std::cout << "\r" << "Solving time step: " << m_p.time.currentTime + m_p.time.currentDT
                      << "/" << m_p.time.simuTime << " s, dt = ";
            std::cout << std::scientific;
            std::cout << m_p.time.currentDT << " s" << std::flush;
        }

        solveCurrentTimeStep();

        if(m_p.time.currentTime >= m_p.time.nextWriteTrigger)
        {
            writeData();
            m_p.time.nextWriteTrigger += m_p.time.simuDTToWrite;
        }

        if(m_p.time.adaptDT)
        {
            double U = 0;
            double c = 0;
            for(std::size_t n = 0 ; n < m_mesh.getNodesNumber() ; ++n)
            {
                if(m_mesh.isNodeBound(n) && m_mesh.isNodeFree(n))
                    continue;

                U = std::max(m_mesh.getNodeState(n, 0)*
                   m_mesh.getNodeState(n, 0) +
                   m_mesh.getNodeState(n, 1)*
                   m_mesh.getNodeState(n, 1), U);

                c = std::max((m_p.fluid.K0 + m_p.fluid.K0prime
                             *m_mesh.getNodeState(n, 2))/m_mesh.getNodeState(n, 3), c);
            }

            U = std::sqrt(U);
            c = std::sqrt(c);

            m_p.time.currentDT = std::min(m_p.time.maxDT,
                                          m_p.time.securityCoeff*m_p.hchar/std::max(U, c));
        }
    }

    std::cout << std::endl;
}

bool SolverCompressible::solveCurrentTimeStep()
{
    buildFrho();

    Eigen::VectorXd qV1half = m_qVPrev + 0.5*m_p.time.currentDT*m_qAccPrev;

    for(std::size_t n = 0 ; n < m_mesh.getNodesNumber() ; ++n)
    {
        if(m_mesh.isNodeFree(n) && !m_mesh.isNodeBound(n))
            qV1half[n + m_mesh.getNodesNumber()] -= m_p.time.currentDT*m_p.gravity*m_mesh.getNodeState(n, 3)*
                                                    m_p.hchar*m_p.hchar*0.5;
    }

    setNodesStatesfromQ(qV1half, 0, 1);
    Eigen::VectorXd deltaPos = qV1half*m_p.time.currentDT;
    m_mesh.updateNodesPosition(std::vector<double> (deltaPos.data(), deltaPos.data() + 2*m_mesh.getNodesNumber()));

    buildMatricesCont();
    applyBoundaryConditionsCont();

    Eigen::VectorXd qRho(m_mesh.getNodesNumber());
    qRho = m_invMrho*m_Frho;
    setNodesStatesfromQ(qRho, 3, 3);
    Eigen::VectorXd qP = getPFromRhoTaitMurnagham(qRho);
    setNodesStatesfromQ(qP, 2, 2);

    buildMatricesMom();
    applyBoundaryConditionsMom();

    m_qAccPrev = m_invM*m_F;

    m_qVPrev = qV1half + 0.5*m_p.time.currentDT*m_qAccPrev;

    setNodesStatesfromQ(m_qVPrev, 0, 1);
    setNodesStatesfromQ(m_qAccPrev, 4, 5);

    m_p.time.currentTime += m_p.time.currentDT;
    m_p.time.currentStep++;

    //Remeshing step
    m_mesh.remesh();

    //We have to compute qPrev here due to new nodes !
    m_qVPrev = getQFromNodesStates(0, 1);
    m_qAccPrev = getQFromNodesStates(4, 5);

    return true;
}

void SolverCompressible::buildFrho()
{
    m_Frho.resize(m_mesh.getNodesNumber()); m_Frho.setZero();

    #pragma omp parallel for default(shared)
    for(std::size_t elm = 0 ; elm < m_mesh.getElementsNumber() ; ++elm)
    {
        Eigen::Vector3d Rho(m_mesh.getNodeState(m_mesh.getElement(elm)[0], 3),
                            m_mesh.getNodeState(m_mesh.getElement(elm)[1], 3),
                            m_mesh.getNodeState(m_mesh.getElement(elm)[2], 3));

        Eigen::MatrixXd Mrhoe = 0.5*m_mesh.getElementDetJ(elm)*m_sumNTN;

        Eigen::VectorXd Frhoe = Mrhoe*Rho;

        //Big push_back ^^
        #pragma omp critical
        {
            for(unsigned short i = 0 ; i < 3 ; ++i)
            {
                /********************************************************************
                                                 Build M
                ********************************************************************/
                m_Frho(m_mesh.getElement(elm)[i]) += Frhoe(i);
            }
        }
    }
}

void SolverCompressible::buildMatricesCont()
{
    m_invMrho.resize(m_mesh.getNodesNumber()); m_invMrho.setZero();

    #pragma omp parallel for default(shared)
    for(std::size_t elm = 0 ; elm < m_mesh.getElementsNumber() ; ++elm)
    {
        Eigen::MatrixXd Mrhoe = 0.5*m_mesh.getElementDetJ(elm)*m_sumNTN;

        for(std::size_t i = 0 ; i < Mrhoe.rows() ; ++i)
        {
            for(std::size_t j = 0 ; j < Mrhoe.cols() ; ++j)
            {
                if(i != j)
                {
                    Mrhoe(i, i) += Mrhoe(i, j);
                    Mrhoe(i, j) = 0;
                }
            }
        }

        //Big push_back ^^
        #pragma omp critical
        {
            for(unsigned short i = 0 ; i < 3 ; ++i)
            {
                /********************************************************************
                                                 Build M
                ********************************************************************/
                m_invMrho.diagonal()[m_mesh.getElement(elm)[i]] += Mrhoe(i,i);
            }
        }
    }

    #pragma omp parallel for default(shared)
    for(std::size_t i = 0 ; i < m_invMrho.rows() ; ++i)
         m_invMrho.diagonal()[i] = 1/m_invMrho.diagonal()[i];
}

void SolverCompressible::buildMatricesMom()
{
    m_invM.resize(2*m_mesh.getNodesNumber()); m_invM.setZero();

    m_F.resize(2*m_mesh.getNodesNumber()); m_F.setZero();

    #pragma omp parallel for default(shared)
    for(std::size_t elm = 0 ; elm < m_mesh.getElementsNumber() ; ++elm)
    {
        Eigen::Vector3d Rho(m_mesh.getNodeState(m_mesh.getElement(elm)[0], 3),
                            m_mesh.getNodeState(m_mesh.getElement(elm)[1], 3),
                            m_mesh.getNodeState(m_mesh.getElement(elm)[2], 3));

        Eigen::VectorXd V(6);
        V << m_mesh.getNodeState(m_mesh.getElement(elm)[0], 0),
             m_mesh.getNodeState(m_mesh.getElement(elm)[1], 0),
             m_mesh.getNodeState(m_mesh.getElement(elm)[2], 0),
             m_mesh.getNodeState(m_mesh.getElement(elm)[0], 1),
             m_mesh.getNodeState(m_mesh.getElement(elm)[1], 1),
             m_mesh.getNodeState(m_mesh.getElement(elm)[2], 1);

        Eigen::Vector3d P(m_mesh.getNodeState(m_mesh.getElement(elm)[0], 2),
                          m_mesh.getNodeState(m_mesh.getElement(elm)[1], 2),
                          m_mesh.getNodeState(m_mesh.getElement(elm)[2], 2));

        Eigen::MatrixXd Be = getB(elm);

        Eigen::MatrixXd Me(6, 6); Me.setZero();
        for(unsigned short k = 0 ; k < m_N.size() ; ++k)
            Me += (m_N[k].topLeftCorner<1,3>()*Rho)*m_N[k].transpose()*m_N[k]*GP2Dweight<double>[k];

        Me *= 0.5*m_mesh.getElementDetJ(elm);

        for(std::size_t i = 0 ; i < Me.rows() ; ++i)
        {
            for(std::size_t j = 0 ; j < Me.cols() ; ++j)
            {
                if(i != j)
                {
                    Me(i, i) += Me(i, j);
                    Me(i, j) = 0;
                }
            }
        }

        //Ke = S Bv^T ddev Bv dV
        Eigen::MatrixXd Ke = 0.5*Be.transpose()*m_ddev*Be*m_mesh.getElementDetJ(elm); //same matrices for all gauss point ^^

        //De = S Np^T m Bv dV
        Eigen::MatrixXd De(3,6); De.setZero();

        for (unsigned short k = 0 ; k < m_N.size() ; ++k)
            De += (m_N[k].topLeftCorner<1,3>()).transpose()*m_m.transpose()*Be*GP2Dweight<double>[k];

        De *= 0.5*m_mesh.getElementDetJ(elm);

        const Eigen::Vector2d b(0, -m_p.gravity);

        //Fe = S Nv^T bodyforce dV
        Eigen::MatrixXd Fe(6,1); Fe.setZero();

        for (unsigned short k = 0 ; k < m_N.size() ; ++k)
            Fe += (m_N[k].topLeftCorner<1,3>()*Rho)*m_N[k].transpose()*b*GP2Dweight<double>[k];

        Fe *= 0.5*m_mesh.getElementDetJ(elm);

        Eigen::MatrixXd FeTot(6,1); FeTot.setZero();
        FeTot = -Ke*V + De.transpose()*P + Fe;

        //Big push_back ^^
        #pragma omp critical
        {
            for(unsigned short i = 0 ; i < 3 ; ++i)
            {
                /********************************************************************
                                             Build M
                ********************************************************************/
                m_invM.diagonal()[m_mesh.getElement(elm)[i]] += Me(i,i);
                m_invM.diagonal()[m_mesh.getElement(elm)[i] + m_mesh.getNodesNumber()] += Me(i + 3, i + 3);

                /************************************************************************
                                                Build f
                ************************************************************************/
                m_F(m_mesh.getElement(elm)[i]) += FeTot(i);
                m_F(m_mesh.getElement(elm)[i] + m_mesh.getNodesNumber()) += FeTot(i + 3);
            }
        }
    }

    #pragma omp parallel for default(shared)
    for(std::size_t i = 0 ; i < 2*m_mesh.getNodesNumber() ; ++i)
        m_invM.diagonal()[i] = 1/m_invM.diagonal()[i];
}

void SolverCompressible::writeData() const
{
    gmsh::model::add("theModel");
    gmsh::model::setCurrent("theModel");
    if(m_p.writeAs == "Nodes" || m_p.writeAs == "NodesElements")
        gmsh::model::addDiscreteEntity(0, 1);
    if(m_p.writeAs == "Elements" || m_p.writeAs == "NodesElements")
        gmsh::model::addDiscreteEntity(2, 2);

    if(m_p.whatToWrite[0])
        gmsh::view::add("u", 1);

    if(m_p.whatToWrite[1])
        gmsh::view::add("v", 2);

    if(m_p.whatToWrite[2])
        gmsh::view::add("p", 3);

    if(m_p.whatToWrite[3])
        gmsh::view::add("ke", 4);

    if(m_p.whatToWrite[4])
        gmsh::view::add("velocity", 5);

    if(m_p.whatToWrite[5])
        gmsh::view::add("rho", 6);

    std::vector<std::size_t> nodesTags(m_mesh.getNodesNumber());
    std::vector<double> nodesCoord(3*m_mesh.getNodesNumber());
    #pragma omp parallel for default(shared)
    for(std::size_t n = 0 ; n < m_mesh.getNodesNumber() ; ++n)
    {
        nodesTags[n] = n + 1;
        nodesCoord[3*n] = m_mesh.getNodePosition(n, 0);
        nodesCoord[3*n + 1] = m_mesh.getNodePosition(n, 1);
        nodesCoord[3*n + 2] = 0;
    }

    gmsh::model::mesh::addNodes(0, 1, nodesTags, nodesCoord);

    if(m_p.writeAs == "Elements" || m_p.writeAs == "NodesElements")
    {
        std::vector<std::size_t> elementTags(m_mesh.getElementsNumber());
        std::vector<std::size_t> nodesTagsPerElement(3*m_mesh.getElementsNumber());
        #pragma omp parallel for default(shared)
        for(std::size_t i = 0 ; i < m_mesh.getElementsNumber() ; ++i)
        {
            elementTags[i] = i + 1;
            nodesTagsPerElement[3*i] = m_mesh.getElement(i)[0] + 1;
            nodesTagsPerElement[3*i + 1] = m_mesh.getElement(i)[1] + 1;
            nodesTagsPerElement[3*i + 2] = m_mesh.getElement(i)[2] + 1;
        }

        gmsh::model::mesh::addElementsByType(2, 2, elementTags, nodesTagsPerElement);
    }

    if(m_p.writeAs == "Nodes" || m_p.writeAs == "NodesElements")
        gmsh::model::mesh::addElementsByType(1, 15, nodesTags, nodesTags);

    std::vector<std::vector<double>> dataU;
    std::vector<std::vector<double>> dataV;
    std::vector<std::vector<double>> dataP;
    std::vector<std::vector<double>> dataKe;
    std::vector<std::vector<double>> dataVelocity;
    std::vector<std::vector<double>> dataRho;

    if(m_p.whatToWrite[0])
        dataU.resize(m_mesh.getNodesNumber());
    if(m_p.whatToWrite[1])
        dataV.resize(m_mesh.getNodesNumber());
    if(m_p.whatToWrite[2])
        dataP.resize(m_mesh.getNodesNumber());
    if(m_p.whatToWrite[3])
        dataKe.resize(m_mesh.getNodesNumber());
    if(m_p.whatToWrite[4])
        dataVelocity.resize(m_mesh.getNodesNumber());
    if(m_p.whatToWrite[5])
        dataRho.resize(m_mesh.getNodesNumber());

    #pragma omp parallel for default(shared)
    for(std::size_t n = 0 ; n < m_mesh.getNodesNumber() ; ++n)
    {
        if(m_p.whatToWrite[0])
        {
            const std::vector<double> u{m_mesh.getNodeState(n, 0)};
            dataU[n] = u;
        }
        if(m_p.whatToWrite[1])
        {
            const std::vector<double> v{m_mesh.getNodeState(n, 1)};
            dataV[n] = v;
        }
        if(m_p.whatToWrite[2])
        {
            const std::vector<double> p{m_mesh.getNodeState(n, 2)};
            dataP[n] = p;
        }
        if(m_p.whatToWrite[3])
        {
            const std::vector<double> ke{0.5*(m_mesh.getNodeState(n, 0)*m_mesh.getNodeState(n, 0)
                                            + m_mesh.getNodeState(n, 1)*m_mesh.getNodeState(n, 1))};
            dataKe[n] = ke;
        }
        if(m_p.whatToWrite[4])
        {
            const std::vector<double> velocity{m_mesh.getNodeState(n, 0), m_mesh.getNodeState(n, 1), 0};
            dataVelocity[n] = velocity;
        }

        if(m_p.whatToWrite[5])
        {
            const std::vector<double> rho{m_mesh.getNodeState(n, 3)};
            dataRho[n] = rho;
        }
    }

    if(m_p.whatToWrite[0])
        gmsh::view::addModelData(1, m_p.time.currentStep, "theModel", "NodeData", nodesTags, dataU, m_p.time.currentTime, 1);
    if(m_p.whatToWrite[1])
        gmsh::view::addModelData(2, m_p.time.currentStep, "theModel", "NodeData", nodesTags, dataV, m_p.time.currentTime, 1);
    if(m_p.whatToWrite[2])
        gmsh::view::addModelData(3, m_p.time.currentStep, "theModel", "NodeData", nodesTags, dataP, m_p.time.currentTime, 1);
    if(m_p.whatToWrite[3])
        gmsh::view::addModelData(4, m_p.time.currentStep, "theModel", "NodeData", nodesTags, dataKe, m_p.time.currentTime, 1);
    if(m_p.whatToWrite[4])
        gmsh::view::addModelData(5, m_p.time.currentStep, "theModel", "NodeData", nodesTags, dataVelocity, m_p.time.currentTime, 3);
    if(m_p.whatToWrite[5])
        gmsh::view::addModelData(6, m_p.time.currentStep, "theModel", "NodeData", nodesTags, dataRho, m_p.time.currentTime, 1);

    const std::string baseName = m_p.resultsName.substr(0, m_p.resultsName.find(".msh"));

    for(unsigned short i = 0; i < m_p.whatToWrite.size(); ++i)
    {
        if(m_p.whatToWrite[i] == true)
            gmsh::view::write(i + 1, baseName + "_" + std::to_string(m_p.time.currentTime) + ".msh" , true);
    }

    gmsh::model::remove();
}