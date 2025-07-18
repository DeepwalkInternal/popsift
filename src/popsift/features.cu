/*
 * Copyright 2016-2017, Simula Research Laboratory
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
#include "common/assist.h"
#include "common/debug_macros.h"
#include "features.h"
#include "sift_extremum.h"
#include "sift_conf.h"

#include <math_constants.h>

#include <cerrno>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <sstream>

using namespace std;

namespace popsift {

/*************************************************************
 * FeaturesBase
 *************************************************************/

FeaturesBase::FeaturesBase( )
    : _num_ext( 0 )
    , _num_ori( 0 )
{ }

FeaturesBase::~FeaturesBase( ) = default;

/*************************************************************
 * FeaturesHost
 *************************************************************/

FeaturesHost::FeaturesHost( )
    : _ext( nullptr )
    , _ori( nullptr )
{ }

FeaturesHost::FeaturesHost( int num_ext, int num_ori )
    : _ext( nullptr )
    , _ori( nullptr )
{
    reset( num_ext, num_ori );
}

FeaturesHost::~FeaturesHost( )
{
    memalign_free( _ext );
    memalign_free( _ori );
}

void FeaturesHost::reset( int num_ext, int num_ori )
{
    if( _ext != nullptr ) { free( _ext ); _ext = nullptr; }
    if( _ori != nullptr ) { free( _ori ); _ori = nullptr; }

    _ext = (Feature*)memalign( getPageSize(), num_ext * sizeof(Feature) );
    if( _ext == nullptr ) {
        std::stringstream ss;
        ss << "Failed to (re)allocate memory for downloading " << num_ext << " features";
        if(errno == EINVAL) ss << " - alignment is not a power of two";
        if(errno == ENOMEM) ss << " - not enough memory";
        throw popsift::MemoryError(ss.str());
    }
    _ori = (Descriptor*)memalign( getPageSize(), num_ori * sizeof(Descriptor) );
    if(_ori == nullptr) {
        std::stringstream ss;
        ss << "Failed to (re)allocate memory for downloading " << num_ori << " descriptors";
        if(errno == EINVAL) ss << " - alignment is not a power of two";
        if(errno == ENOMEM) ss << " - not enough memory";
        throw popsift::MemoryError(ss.str());
    }

    setFeatureCount( num_ext );
    setDescriptorCount( num_ori );
}

void FeaturesHost::pin( )
{
    cudaError_t err;
    err = cudaHostRegister( _ext, getFeatureCount() * sizeof(Feature), 0 );
    if( err != cudaSuccess ) {
        cerr << __FILE__ << ":" << __LINE__ << " Runtime warning:" << endl
             << "    Failed to register feature memory in CUDA." << endl
             << "    Features count: " << getFeatureCount() << endl
             << "    Memory size requested: " << getFeatureCount() * sizeof(Feature) << endl
             << "    " << cudaGetErrorString(err) << endl;
    }
    err = cudaHostRegister( _ori, getDescriptorCount() * sizeof(Descriptor), 0 );
    if( err != cudaSuccess ) {
        cerr << __FILE__ << ":" << __LINE__ << " Runtime warning:" << endl
             << "    Failed to register descriptor memory in CUDA." << endl
             << "    Descriptors count: " << getDescriptorCount() << endl
             << "    Memory size requested: " << getDescriptorCount() * sizeof(Descriptor) << endl
             << "    " << cudaGetErrorString(err) << endl;
    }
}

void FeaturesHost::unpin( )
{
    cudaHostUnregister( _ext );
    cudaHostUnregister( _ori );
}

void FeaturesHost::print( std::ostream& ostr, bool write_as_uchar ) const
{
    for( int i=0; i<size(); i++ ) {
        _ext[i].print( ostr, write_as_uchar );
    }
}

std::ostream& operator<<( std::ostream& ostr, const FeaturesHost& feature )
{
    feature.print( ostr, false );
    return ostr;
}

/*************************************************************
 * FeaturesDev
 *************************************************************/

FeaturesDev::FeaturesDev( )
    : _ext( nullptr )
    , _ori( nullptr )
    , _rev( nullptr )
{ }

FeaturesDev::FeaturesDev( int num_ext, int num_ori )
    : _ext( nullptr )
    , _ori( nullptr )
    , _rev( nullptr )
{
    reset( num_ext, num_ori );
}

FeaturesDev::~FeaturesDev( )
{
    cudaFree( _ext );
    cudaFree( _ori );
    cudaFree( _rev );
}

void FeaturesDev::reset( int num_ext, int num_ori )
{
    if( _ext != nullptr ) { cudaFree( _ext ); _ext = nullptr; }
    if( _ori != nullptr ) { cudaFree( _ori ); _ori = nullptr; }
    if( _rev != nullptr ) { cudaFree( _rev ); _rev = nullptr; }

    _ext = popsift::cuda::malloc_devT<Feature>   ( num_ext, __FILE__, __LINE__ );
    _ori = popsift::cuda::malloc_devT<Descriptor>( num_ori, __FILE__, __LINE__ );
    _rev = popsift::cuda::malloc_devT<int>       ( num_ori, __FILE__, __LINE__ );

    setFeatureCount( num_ext );
    setDescriptorCount( num_ori );
}



/*************************************************************
 * Feature
 *************************************************************/

void Feature::print( std::ostream& ostr, bool write_as_uchar ) const
{
    float sigval =  1.0f / ( sigma * sigma );

    for( int ori=0; ori<num_ori; ori++ ) {
        ostr << xpos << " " << ypos << " "
             << sigval << " 0 " << sigval << " ";
        if( write_as_uchar ) {
            for( int i=0; i<128; i++ ) {
                ostr << roundf(desc[ori]->features[i]) << " ";
            }
        } else {
            ostr << std::setprecision(3);
            for( int i=0; i<128; i++ ) {
                ostr << desc[ori]->features[i] << " ";
            }
            ostr << std::setprecision(6);
        }
        ostr << std::endl;
    }
}

std::ostream& operator<<( std::ostream& ostr, const Feature& feature )
{
    feature.print( ostr, false );
    return ostr;
}

} // namespace popsift
