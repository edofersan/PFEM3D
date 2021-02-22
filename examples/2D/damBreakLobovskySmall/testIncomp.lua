Problem = {
    id = "IncompNewtonNoT",
	simulationTime = 6,
	verboseOutput = false,
	
	Mesh = {
		hchar = 0.015,
		alpha = 1.2,
		adaptAlpha = false,
		alphaMax   = 1.4,
		alphaMin   = 1.0,
		Dalpha     = 0.025,
		MassTol    = 0.02,
		omega = 0.8,
		gamma = 0.8,
		boundingBox = {-0.01, -0.01, 1.62, 10.00},
		mshFile = "examples/2D/damBreakLobovskySmall/geometry.msh"
	},
	
	Extractors = {
		{
			kind = "MinMax",
			outputFile = "tipPosition.txt",
			timeBetweenWriting = 0.01,
			minMax = "max",
			coordinate = 0 
		},
		{
			kind = "GMSH",
			outputFile = "results.msh",
			timeBetweenWriting = 0.05,
			whatToWrite = {"p", "ke"},
			writeAs = "NodesElements" 
		},
		{
			kind = "Mass",
			outputFile = "mass.txt",
			timeBetweenWriting = 0.01,
		},
		{
			kind = "Alpha",
			outputFile = "alpha.txt",
			timeBetweenWriting = 0.01,
		}
	},
	
	Material = {
		mu = 0.887e-3,
		rho = 997,
		gamma = 0
	},
	
	IC = {
		BoundaryFixed = true
	},
	
	Solver = {
	    id = "PSPG",
		adaptDT = true,
		coeffDTincrease = 1.3,
		coeffDTDecrease = 2.5,
		maxDT = 0.001,
		initialDT = 0.001,
		
		MomContEq = {
			minRes = 1e-6,
			maxIter = 10,
			bodyForce = {0, -9.81},
			BC = {

			}
		}
	}
}

function Problem.IC:initStates(pos)
	return {0, 0, 0}
end

function Problem.Solver.MomContEq.BC:BoundaryV(pos, initPos, states, t)
	return {0, 0}
end