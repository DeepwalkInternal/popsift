/*
 * Copyright 2016-2017, Simula Research Laboratory
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
#include "matching.h"
#include "features.h"
#include "common/assist.h"
#include "common/debug_macros.h"
#include "sift_extremum.h"

#include <math_constants.h>
#include <iostream>

using namespace std;

namespace popsift {

/*************************************************************
 * CUDA kernels for matching
 *************************************************************/

__device__ inline float
l2_in_t0( const float4* lptr, const float4* rptr )
{
    const float4  lval = lptr[threadIdx.x];
    const float4  rval = rptr[threadIdx.x];
    const float4  mval = make_float4( lval.x - rval.x,
			              lval.y - rval.y,
			              lval.z - rval.z,
			              lval.w - rval.w );
    float   res = mval.x * mval.x
	        + mval.y * mval.y
	        + mval.z * mval.z
	        + mval.w * mval.w;
    res += shuffle_down( res, 16 );
    res += shuffle_down( res,  8 );
    res += shuffle_down( res,  4 );
    res += shuffle_down( res,  2 );
    res += shuffle_down( res,  1 );
    return res;
}

__global__ void
compute_distance( int3* match_matrix, Descriptor* l, int l_len, Descriptor* r, int r_len )
{
    if( blockIdx.x >= l_len ) return;
    const int idx = blockIdx.x;

    float match_1st_val = CUDART_INF_F;
    float match_2nd_val = CUDART_INF_F;
    int   match_1st_idx = 0;
    int   match_2nd_idx = 0;

    const float4* lptr = (const float4*)( &l[idx] );

    for( int i=0; i<r_len; i++ )
    {
        const float4* rptr = (const float4*)( &r[i] );

        const float   res  = l2_in_t0( lptr, rptr );

        if( threadIdx.x == 0 )
        {
            if( res < match_1st_val )
            {
                match_2nd_val = match_1st_val;
                match_2nd_idx = match_1st_idx;
                match_1st_val = res;
                match_1st_idx = i;
            }
            else if( res < match_2nd_val )
            {
                match_2nd_val = res;
                match_2nd_idx = i;
            }
        }
        __syncthreads();
    }

    if( threadIdx.x == 0 )
    {
        bool accept = ( match_1st_val / match_2nd_val < 0.8f );
        match_matrix[blockIdx.x] = make_int3( match_1st_idx, match_2nd_idx, accept );
    }
}

/*************************************************************
 * MatchResults implementation
 *************************************************************/

int MatchResults::getNumAcceptedMatches() const
{
    int count = 0;
    for (const auto& match : _matches) {
        if (match.is_accepted) {
            count++;
        }
    }
    return count;
}

/*************************************************************
 * Matching function implementation
 *************************************************************/

MatchResults match_features( FeaturesDev* left, FeaturesDev* right )
{
    int l_len = left->getDescriptorCount( );
    int r_len = right->getDescriptorCount( );

    int3* match_matrix = popsift::cuda::malloc_devT<int3>( l_len, __FILE__, __LINE__ );

    dim3 grid;
    grid.x = l_len;
    grid.y = 1;
    grid.z = 1;
    dim3 block;
    block.x = 32;
    block.y = 1;
    block.z = 1;

    compute_distance
        <<<grid,block>>>
        ( match_matrix, left->getDescriptors(), l_len, right->getDescriptors(), r_len );

    POP_SYNC_CHK;

    // Download match matrix to host to populate results
    int3* host_match_matrix = new int3[l_len];
    cudaMemcpy( host_match_matrix, match_matrix, l_len * sizeof(int3), cudaMemcpyDeviceToHost );

    // Download reverse maps to map descriptor indices to feature indices
    int* left_rev_map = new int[l_len];
    int* right_rev_map = new int[r_len];
    cudaMemcpy( left_rev_map, left->getReverseMap(), l_len * sizeof(int), cudaMemcpyDeviceToHost );
    cudaMemcpy( right_rev_map, right->getReverseMap(), r_len * sizeof(int), cudaMemcpyDeviceToHost );

    // Create match results
    MatchResults results(l_len);
    
    // Calculate actual distances for result storage
    Descriptor* left_desc = new Descriptor[l_len];
    Descriptor* right_desc = new Descriptor[r_len];
    cudaMemcpy( left_desc, left->getDescriptors(), l_len * sizeof(Descriptor), cudaMemcpyDeviceToHost );
    cudaMemcpy( right_desc, right->getDescriptors(), r_len * sizeof(Descriptor), cudaMemcpyDeviceToHost );

    for( int i = 0; i < l_len; i++ )
    {
        Match match;
        match.left_descriptor_idx = i;
        match.left_feature_idx = left_rev_map[i];
        match.right_descriptor_idx = host_match_matrix[i].x;
        match.right_feature_idx = right_rev_map[host_match_matrix[i].x];
        match.second_best_idx = host_match_matrix[i].y;
        match.is_accepted = (host_match_matrix[i].z != 0);
        
        // Calculate actual distances
        match.best_distance = 0.0f;
        match.second_best_distance = 0.0f;
        
        for( int j = 0; j < 128; j++ )
        {
            float diff1 = left_desc[i].features[j] - right_desc[match.right_descriptor_idx].features[j];
            float diff2 = left_desc[i].features[j] - right_desc[match.second_best_idx].features[j];
            match.best_distance += diff1 * diff1;
            match.second_best_distance += diff2 * diff2;
        }
        
        results.addMatch(match);
    }

    // Cleanup
    delete[] host_match_matrix;
    delete[] left_rev_map;
    delete[] right_rev_map;
    delete[] left_desc;
    delete[] right_desc;
    cudaFree( match_matrix );
    
    return results;
}

} // namespace popsift 