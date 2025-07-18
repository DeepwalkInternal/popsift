/*
 * Copyright 2016-2017, Simula Research Laboratory
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
#pragma once

#include <vector>

namespace popsift {

// Forward declarations
class FeaturesDev;

/**
 * @brief A single feature match result
 */
struct Match
{
    int left_feature_idx;       // Index of the left feature
    int left_descriptor_idx;    // Index of the left descriptor
    int right_feature_idx;      // Index of the best matching right feature
    int right_descriptor_idx;   // Index of the best matching right descriptor
    int second_best_idx;        // Index of the second best matching right descriptor
    float best_distance;        // Distance to the best match
    float second_best_distance; // Distance to the second best match
    bool is_accepted;           // Whether this match passes the ratio test
};

/**
 * @brief Container for all match results between two feature sets
 */
class MatchResults
{
private:
    std::vector<Match> _matches;

public:
    MatchResults() = default;
    MatchResults(int num_matches) { _matches.reserve(num_matches); }
    
    void addMatch(const Match& match) { _matches.push_back(match); }
    void reserve(int num_matches) { _matches.reserve(num_matches); }
    
    const std::vector<Match>& getMatches() const { return _matches; }
    int getNumMatches() const { return _matches.size(); }
    int getNumAcceptedMatches() const;
    
    // Iterator support
    std::vector<Match>::const_iterator begin() const { return _matches.begin(); }
    std::vector<Match>::const_iterator end() const { return _matches.end(); }
};

/**
 * @brief Match features between two FeaturesDev objects
 * @param[in] left Left features to match
 * @param[in] right Right features to match against
 * @return MatchResults containing all match information
 */
MatchResults match_features( FeaturesDev* left, FeaturesDev* right );

} // namespace popsift 