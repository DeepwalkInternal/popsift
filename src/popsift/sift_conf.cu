/*
 * Copyright 2016, Simula Research Laboratory
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
#include "common/debug_macros.h"
#include "sift_conf.h"


using namespace std;

namespace popsift
{

Config::Config( )
    : _upscale_factor( 1.0f )
    , octaves( -1 )
    , levels( 3 )
    , sigma( 1.6f )
    , _edge_limit( 10.0f )
    , _threshold( 0.04 ) // ( 10.0f / 256.0f )
    , _gauss_mode( getGaussModeDefault() )
    , _sift_mode( Config::PopSift )
    , _log_mode( Config::None )
    , _scaling_mode( Config::ScaleDefault )
    , _desc_mode( Config::Loop )
    , _grid_filter_mode( Config::RandomScale )
    , verbose( false )
    // , _max_extrema( 20000 )
    , _max_extrema( 100000 )
    , _filter_max_extrema( -1 )
    , _filter_grid_size( 2 )
    , _assume_initial_blur( true )
    , _initial_blur( 0.5f )
    , _normalization_mode( getNormModeDefault() )
    , _normalization_multiplier( 0 )
    , _print_gauss_tables( false )
{
    int            currentDev;
    cudaDeviceProp currentProp;
    cudaError_t    err;

    err = cudaGetDevice( &currentDev );
    POP_CUDA_FATAL_TEST( err, "Could not get current device ID" );

    err = cudaGetDeviceProperties( &currentProp, currentDev );
    POP_CUDA_FATAL_TEST( err, "Could not get current device properties" );
}

void Config::setSiftMode( Config::SiftMode mode )
{
    _sift_mode = mode;
}

void Config::setGaussMode( Config::GaussMode mode )
{
    _gauss_mode = mode;
}

void Config::setDescMode( const std::string& mode )
{
    if( mode == "loop" )
        setDescMode( Config::Loop );
    else if( mode == "iloop" )
        setDescMode( Config::ILoop );
    else if( mode == "grid" )
        setDescMode( Config::Grid );
    else if( mode == "igrid" )
        setDescMode( Config::IGrid );
    else if( mode == "notile" )
        setDescMode( Config::NoTile );
    else
        throw InvalidEnumError("descriptor mode", mode, "loop, iloop, grid, igrid, notile");
}

void Config::setDescMode( Config::DescMode mode )
{
    _desc_mode = mode;
}

void Config::setGaussMode( const std::string& mode )
{
    if( mode == "vlfeat" )
        setGaussMode( Config::VLFeat_Compute );
    else if( mode == "vlfeat-hw-interpolated" )
        setGaussMode( Config::VLFeat_Relative );
    else if( mode == "relative" )
        setGaussMode( Config::VLFeat_Relative );
    else if( mode == "vlfeat-direct" )
        setGaussMode( Config::VLFeat_Relative_All );
    else if( mode == "opencv" )
        setGaussMode( Config::OpenCV_Compute );
    else if( mode == "fixed9" )
        setGaussMode( Config::Fixed9 );
    else if( mode == "fixed15" )
        setGaussMode( Config::Fixed15 );
    else
        throw InvalidEnumError("Gauss mode", mode, getGaussModeUsage());
}

Config::GaussMode Config::getGaussModeDefault( )
{
    return Config::VLFeat_Compute;
}

const char* Config::getGaussModeUsage( )
{
    return
        "Choice of Gauss filter method. "
        "Options are: "
        "vlfeat (default), "
        "vlfeat-hw-interpolated, "
        "vlfeat-direct, "
        "opencv, "
        "fixed9, "
        "fixed15, "
        "relative (synonym for vlfeat-hw-interpolated)";
}

bool Config::getCanFilterExtrema() const
{
#if __CUDACC_VER_MAJOR__ >= 8
    return true;
#else
    return false;
#endif
}

void Config::setFilterSorting( const std::string& text )
{
    if( text == "up" )
        _grid_filter_mode = Config::SmallestScaleFirst;
    else if( text == "down" )
        _grid_filter_mode = Config::LargestScaleFirst;
    else if( text == "random" )
        _grid_filter_mode = Config::RandomScale;
    else
        throw InvalidEnumError("filter sorting mode", text, "up, down, random");
}

void Config::setFilterSorting( Config::GridFilterMode m )
{
    _grid_filter_mode = m;
}

void Config::setVerbose( bool on )
{
    verbose = on;
}

void Config::setLogMode( LogMode mode )
{
    _log_mode = mode;
}

Config::LogMode Config::getLogMode( ) const
{
    return _log_mode;
}

void Config::setScalingMode( ScalingMode mode )
{
    _scaling_mode = mode;
}


Config::NormMode Config::getNormMode( ) const 
{
    return _normalization_mode;
}

void Config::setNormMode( Config::NormMode m )
{
    _normalization_mode = m;
}

void Config::setNormMode( const std::string& m )
{
    if( m == "RootSift" ) setNormMode( Config::RootSift );
    else if( m == "classic" ) setNormMode( Config::Classic );
    else
        throw InvalidEnumError("normalization mode", m, getNormModeUsage());
}

Config::NormMode Config::getNormModeDefault( )
{
    return Config::RootSift;
}

const char* Config::getNormModeUsage( )
{
    return
        "Choice of descriptor normalization modes. "
        "Options are: "
        "RootSift (L1-like, default), "
        "Classic (L2-like)";
}

/**
 * Normalization multiplier
 * A power of 2 multiplied with the normalized descriptor. Required
 * for the construction of 1-byte integer desciptors.
 * Usual choice is 2^8 or 2^9.
 */
void Config::setNormalizationMultiplier( int mul )
{
    _normalization_multiplier = mul;
}

int Config::getNormalizationMultiplier( ) const
{
    return _normalization_multiplier;
}

void Config::setUpscaleFactor( float v ) { _upscale_factor = v; }

void Config::setOctaves( int v ) { 
    if (v < -1) {
        throw ParameterRangeError("octaves", std::to_string(v), ">= -1 (use -1 for auto)");
    }
    octaves = v; 
}

void Config::setLevels( int v ) { 
    if (v < 1 || v > 10) {
        throw ParameterRangeError("levels", std::to_string(v), "1-10");
    }
    levels = v; 
}

void Config::setSigma( float v ) { 
    if (v <= 0.0f || v > 10.0f) {
        throw ParameterRangeError("sigma", std::to_string(v), "> 0.0 and <= 10.0");
    }
    sigma = v; 
}

void Config::setEdgeLimit( float v ) { 
    if (v < 0.0f) {
        throw ParameterRangeError("edge_limit", std::to_string(v), ">= 0.0");
    }
    _edge_limit = v; 
}

void Config::setThreshold( float v ) { 
    if (v < 0.0f) {
        throw ParameterRangeError("threshold", std::to_string(v), ">= 0.0");
    }
    _threshold = v; 
}

void Config::setPrintGaussTables() { _print_gauss_tables = true; }

void Config::setFilterMaxExtrema( int ext ) { 
    if (ext < -1) {
        throw ParameterRangeError("filter_max_extrema", std::to_string(ext), ">= -1 (use -1 for auto)");
    }
    _filter_max_extrema = ext; 
}

void Config::setFilterGridSize( int sz ) { 
    if (sz < 1 || sz > 10) {
        throw ParameterRangeError("filter_grid_size", std::to_string(sz), "1-10");
    }
    _filter_grid_size = sz; 
}

void Config::setInitialBlur( float blur )
{
    if( blur == 0.0f ) {
        _assume_initial_blur = false;
        _initial_blur        = blur;
    } else {
        _assume_initial_blur = true;
        _initial_blur        = blur;
    }
}

Config::GaussMode Config::getGaussMode( ) const
{
    return _gauss_mode;
}

Config::SiftMode Config::getSiftMode() const
{
    return _sift_mode;
}

bool Config::hasInitialBlur( ) const
{
    return _assume_initial_blur;
}

float Config::getInitialBlur( ) const
{
    return _initial_blur;
}

float Config::getPeakThreshold() const
{
    return ( _threshold * 0.5f * 255.0f / levels );
}

bool Config::ifPrintGaussTables() const
{
    return _print_gauss_tables;
}

bool Config::equal( const Config& other ) const
{
    #define COMPARE(a) ( this->a != other.a )
    if( COMPARE( octaves ) ||
        COMPARE( levels ) ||
        COMPARE( sigma ) ||
        COMPARE( _edge_limit ) ||
        COMPARE( _threshold ) ||
        COMPARE( _upscale_factor ) ||
        COMPARE( _scaling_mode ) ||
        COMPARE( _max_extrema ) ||
        COMPARE( _gauss_mode ) ||
        COMPARE( _sift_mode ) ||
        COMPARE( _assume_initial_blur ) ||
        COMPARE( _initial_blur ) ||
        COMPARE( _normalization_mode ) ||
        COMPARE( _normalization_multiplier ) ) return false;
    return true;
}

}; // namespace popsift

