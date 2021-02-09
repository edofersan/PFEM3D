#pragma once
#ifndef ALPHAEXTRACTOR_HPP_INCLUDED
#define ALPHAEXTRACTOR_HPP_INCLUDED

#include <fstream>

#include "Extractor.hpp"

class SIMULATION_API AlphaExtractor : public Extractor
{
    public:
        AlphaExtractor()                                              = delete;
        AlphaExtractor(Problem* pProblem, const std::string& outFileName, double timeBetweenWriting);
        AlphaExtractor(const AlphaExtractor& alphaExtractor)            = delete;
        AlphaExtractor& operator=(const AlphaExtractor& alphaExtractor) = delete;
        AlphaExtractor(AlphaExtractor&& alphaExtractor)                 = delete;
        AlphaExtractor& operator=(AlphaExtractor&& alphaExtractor)      = delete;
        ~AlphaExtractor() override;

        void update() override;

    private:
        std::ofstream m_outFile;
};

#endif // ALPHAEXTRACTOR_HPP_INCLUDED
