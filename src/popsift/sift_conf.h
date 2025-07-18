/*
 * Copyright 2016, Simula Research Laboratory
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
#pragma once

#include <stdexcept>
#include <string>

#define MAX_OCTAVES   20
#define MAX_LEVELS    10

#undef USE_DOG_TEX_LINEAR

#ifdef _MSC_VER
#define DEPRECATED(func) __declspec(deprecated) func
#elif defined(__GNUC__) || defined(__clang__)
#define DEPRECATED(func) func __attribute__ ((deprecated))
#else
#endif

namespace popsift {

/**
 * @brief Exception thrown when an invalid configuration parameter is provided
 */
class ConfigError : public std::invalid_argument {
public:
    explicit ConfigError(const std::string& message) : std::invalid_argument(message) {}
};

/**
 * @brief Exception thrown when an invalid enum value is provided
 */
class InvalidEnumError : public ConfigError {
public:
    explicit InvalidEnumError(const std::string& enum_name, const std::string& value, const std::string& valid_options)
        : ConfigError("Invalid " + enum_name + " value: '" + value + "'. Valid options are: " + valid_options) {}
};

/**
 * @brief Exception thrown when a parameter is out of valid range
 */
class ParameterRangeError : public ConfigError {
public:
    explicit ParameterRangeError(const std::string& param_name, const std::string& value, const std::string& valid_range)
        : ConfigError("Parameter '" + param_name + "' value '" + value + "' is out of valid range: " + valid_range) {}
};

/**
 * @brief Exception thrown for memory allocation failures
 */
class MemoryError : public std::runtime_error {
public:
    explicit MemoryError(const std::string& message) : std::runtime_error("Memory error: " + message) {}
};

/**
 * @brief Exception thrown for CUDA-related errors
 */
class CudaError : public std::runtime_error {
public:
    explicit CudaError(const std::string& message) : std::runtime_error("CUDA error: " + message) {}
};

/**
 * @brief Exception thrown for image processing errors
 */
class ImageError : public std::runtime_error {
public:
    explicit ImageError(const std::string& message) : std::runtime_error("Image error: " + message) {}
};

/**
 * @brief Exception thrown for unsupported operations
 */
class UnsupportedOperationError : public std::runtime_error {
public:
    explicit UnsupportedOperationError(const std::string& message) : std::runtime_error("Unsupported operation: " + message) {}
};

/**
 * @brief Exception thrown for internal logic errors
 */
class LogicError : public std::runtime_error {
public:
    explicit LogicError(const std::string& message) : std::runtime_error("Logic error: " + message) {}
};

struct Config
{
    Config();

    /**
     * @brief The way the gaussian mode is compute.
     *
     * Each setting allows to mimic and reproduce the behaviour of other Sift implementations.
     */
    enum GaussMode
    {
        VLFeat_Compute,
        VLFeat_Relative,
        VLFeat_Relative_All,
        OpenCV_Compute,
        Fixed9,
        Fixed15
    };

    /**
     * @brief General setting to reproduce the results of other Sift implementations.
     */
    enum SiftMode
    {
        /// Popsift implementation
        PopSift,
        /// OpenCV implementation
        OpenCV,
        /// VLFeat implementation
        VLFeat,
        /// Default implementation is PopSift
        Default = PopSift
    };

    /**
     * @brief The logging mode.
     */
    enum LogMode
    {
        None,
        All
    };

    /**
     * @brief The scaling mode.
     */
    enum ScalingMode
    {
        ScaleDirect,
        /// Indirect - only working method
        ScaleDefault
    };

    /**
     * @brief Modes for descriptor extraction.
     */
    enum DescMode
    {
        /// scan horizontal, extract valid points
        Loop,
        /// scan horizontal, extract valid points, interpolate with tex engine
        ILoop,
        /// scan in rotated mode, round pixel address
        Grid,
        /// scan in rotated mode, interpolate with tex engine
        IGrid,
        /// variant of IGrid, no duplicate gradient fetching
        NoTile
    };

    /**
     * @brief Type of norm to use for matching.
     */
    enum NormMode
    {
        /// The L1-inspired norm, gives better matching results ("RootSift")
        RootSift,
        /// The L2-inspired norm, all descriptors on a hypersphere ("classic")
        Classic
    };

    /**
     * @brief Filtering strategy.
     * 
     * To reduce time used in descriptor extraction, some extrema can be filtered
     * immediately after finding them. It is possible to keep those with the largest
     * scale (LargestScaleFirst), smallest scale (SmallestScaleFirst), or a random
     * selection. Note that largest and smallest give a stable result, random does not.
     */
    enum GridFilterMode {
        /// keep a random selection
        RandomScale,
        /// keep those with the largest scale
        LargestScaleFirst,
        /// keep those with the smallest scale
        SmallestScaleFirst
    };

    /**
     * @brief Processing mode. 
     * 
     * Determines which data is kept in the Job data structure after processing, which one is downloaded to the host,
     * which one is invalidated.
     */
    enum ProcessingMode {
        ExtractingMode,
        MatchingMode
    };

    /**
     * @brief Set the Gaussian mode from string.
     * @param[in] mode The string version of the GaussMode
     * @see GaussMode
     */
    void setGaussMode( const std::string& mode );
    /**
     * @brief Set the Gaussian mode.
     * @param[in] mode The Gaussian mode to use.
     * @see GaussMode
     */
    void setGaussMode( GaussMode mode );

    /**
     * @brief Set the SIFT mode.
     * @param[in] mode The SIFT mode
     * @see SiftMode
     */
    void setSiftMode( SiftMode mode );

    /**
     * @brief Set the log mode.
     * @param[in] mode The log mode.
     * @see LogMode
     */
    void setLogMode( LogMode mode = All );
    
    /**
     * @brief Set the scaling mode.
     * @param[in] mode The scaling mode.
     * @see ScalingMode
     */
    void setScalingMode( ScalingMode mode = ScaleDefault );

    /**
     * @brief Enable/disable verbose mode.
     * @param[in] enabled Whether to display additional information.
     */
    void setVerbose( bool enabled = true );

    /**
     * @brief Set the descriptor mode by string.
     * @param[in] mode The string containing the descriptor mode.
     * @see DescMode
     */
    void setDescMode( const std::string& mode );

    /**
    * @brief Set the descriptor mode.
    * @param[in] mode The descriptor mode.
    * @see DescMode
    */
    void setDescMode( DescMode mode = Loop );

//    void setGaussGroup( int groupsize );
//    int  getGaussGroup( ) const;

    void setUpscaleFactor( float factor );
    void setOctaves( int octaves );
    void setLevels( int levels );
    void setSigma( float sigma );
    void setEdgeLimit( float limit );
    void setThreshold( float threshold );
    void setInitialBlur( float blur );
//    void setMaxExtreme( int m );
    void setPrintGaussTables( );
//    void setDPOrientation( bool on );
    void setFilterMaxExtrema( int extrema );
    void setFilterGridSize( int size );
    void setFilterSorting( const std::string& direction );
    void setFilterSorting( GridFilterMode mode );

    bool  hasInitialBlur( ) const;
    float getInitialBlur( ) const;

    /// computes the actual peak threshold depending on the threshold
    /// parameter and the non-augmented number of levels
    float getPeakThreshold() const;

    /// print Gauss spans and tables?
    bool ifPrintGaussTables() const;

    /// What Gauss filter scan is desired?
    GaussMode getGaussMode( ) const;

    /// Call this from the constructor.
    static GaussMode getGaussModeDefault( );


    // Helper functions for the main program's usage string.
    /**
     * @brief Get a message with the strings to use for setting the values of \p GaussMode
     * @return  A message with the list of strings
     */
    static const char* getGaussModeUsage( );

    /**
     * @brief Get the SIFT mode for more detailed sub-modes
     * @return The SiftMode
     * @see SiftMode
     */
    SiftMode getSiftMode( ) const;

    /// find out if we should print logging info or not
    LogMode getLogMode( ) const;

    /// The number of octaves is chosen freely. If not specified,
    /// it is: log_2( min(x,y) ) - 3 - start_sampling
    int      octaves;

    /// The number of levels per octave. This is actually the
    /// number of inner DoG levels where we can search for
    /// feature points. The number of ...
    ///
    /// This is the non-augmented number of levels, meaning
    /// the this is not the number of gauss-filtered picture
    /// layers (which is levels+3), but the number of DoG
    /// layers in which we can search for extrema.
    int      levels;
    float    sigma;

    /// default edge_limit 16.0f from Celebrandil
    /// default edge_limit 10.0f from Bemap
    float    _edge_limit;

    /** Functions related to descriptor normalization: L2-like or RootSift
     */
    void               setNormMode( NormMode m );
    void               setNormMode( const std::string& m );
    /**
     * @brief Get the current normalization mode.
     * @return The current normalization mode.
     * @see NormMode
     */
    NormMode           getNormMode( ) const;
    /**
     * @brief Get the normalization mode (deprecated - parameter is ignored).
     * @param[in] m This parameter is ignored and will be removed in a future version.
     * @return The current normalization mode.
     * @see NormMode
     */
    static NormMode    getNormModeDefault( ); // Call this from the constructor.
    static const char* getNormModeUsage( );  // Helper functions for the main program's usage string.

    /**
     * @brief Functions related to descriptor normalization: multiply with a power of 2
     */
    int  getNormalizationMultiplier( ) const;
    void setNormalizationMultiplier( int mul );

    /**
     * @brief The input image is stretched by 2^upscale_factor
     * before processing. The factor 1 is default.
     */
    inline float getUpscaleFactor( ) const {
        return _upscale_factor;
    }

    inline float getThreshold( ) const {
        return _threshold;
    }

    inline int getOctaves( ) const {
        return octaves;
    }

    inline int getLevels( ) const {
        return levels;
    }

    inline float getSigma( ) const {
        return sigma;
    }

    inline float getEdgeLimit( ) const {
        return _edge_limit;
    }

    int getMaxExtrema( ) const {
        return _max_extrema;
    }

    /**
     * Have we enabled filtering? This is a compile time decision.
     * The reason is that we use Thrust, which increases compile 
     * considerably and can be deactivated at the CMake level when
     * you work on something else.
     */
    bool getCanFilterExtrema() const;

    /**
     * Set the approximate number of extrema whose orientation and descriptor
     * should be computed. Default is -1, which sets the hard limit defined
     * by "number of octaves * getMaxExtrema()".
     */
    int getFilterMaxExtrema() const { return _filter_max_extrema; }

    /**
     * @brief Get the grid size for filtering.
     *
     * To avoid that grid filtering happens only in a tiny piece of an image,
     * the image is split into getFilterGridSize() X getFilterGridSize() tiles
     * and we allow getFilterMaxExtrema() / getFilterGridSize() extrema in
     * each tile.
     */
    int getFilterGridSize() const { return _filter_grid_size; }

    /**
     * @brief Get the filtering mode.
     * @return the filtering mode.
     * @see GridFilterMode
     */
    GridFilterMode getFilterSorting() const { return _grid_filter_mode; }

    /**
     * @brief Get the scaling mode.
     * @return the descriptor extraction mode.
     * @see ScalingMode
     */
    inline ScalingMode getScalingMode() const { return _scaling_mode; }

    /**
     * @brief Get the descriptor extraction mode
     * @return the descriptor extraction mode
     * @see DescMode
     */
    inline DescMode getDescMode() const { return _desc_mode; }

    bool equal( const Config& other ) const;

private:
    /// default threshold 0.0 default of vlFeat
    /// default threshold 5.0 / 256.0
    /// default threshold 15.0 / 256.0 - it seems our DoG is really small ???
    /// default threshold 5.0 from Celebrandil, not happening in our data
    /// default threshold 0.04 / (_levels-3.0) / 2.0f * 255
    ///                   from Bemap -> 1.69 (makes no sense)
    float    _threshold;

    /// determine the image format of the first octave
    /// relative to the input image's size (x,y) as follows:
    /// (x / 2^start_sampling, y / 2^start_sampling )
    float    _upscale_factor;

    /// default LogMode::None
    LogMode  _log_mode;

    /// default: ScalingMode::DownscaledOctaves
    ScalingMode _scaling_mode;

    /// default: DescMode::Loop
    DescMode    _desc_mode;

    /// default: RandomScale
    GridFilterMode _grid_filter_mode;

public:
    bool     verbose;

private:
    /// The number of initial extrema that can be discovered in an octave.
    /// This parameter changes memory requirements.
    int _max_extrema;

    /// The maximum number of extrema that are returned. There may be
    /// several descriptors for each extremum.
    int _filter_max_extrema;

    /// Used to achieve an approximation of _max_entrema
    /// Subdivide the image in this number of vertical and horizontal tiles,
    /// i.e. the grid is actually _grid_size X _grid_size tiles.
    /// default: 1
    int  _filter_grid_size;

    /// Modes are computation according to VLFeat or OpenCV,
    /// or fixed size. Default is VLFeat mode.
    GaussMode _gauss_mode;

    /// Modes are PopSift, OpenCV and VLFeat.
    /// Default is currently identical to PopSift.
    SiftMode _sift_mode;

    /// VLFeat code assumes that an initial input image is partially blurred.
    /// This changes the blur computation for the very first level of the first
    /// octave, turning it into a special case.
    bool  _assume_initial_blur;
    float _initial_blur;

    /// OpenMVG requires a normalization named rootSift, the
    /// classical L2-inspired mode is also supported.
    NormMode _normalization_mode;

    /// SIFT descriptors are normalized in a final step.
    /// The values of the descriptor can also be multiplied
    /// by a power of 2 if required.
    /// Specify the exponent.
    int _normalization_multiplier;

    /// Call the debug functions in gauss_filter.cu to print Gauss
    /// filter width and Gauss tables in use.
    bool _print_gauss_tables;
};

inline bool operator==( const Config& l, const Config& r )
{
    return l.equal( r );
}

inline bool operator!=( const Config& l, const Config& r )
{
    return ! l.equal( r );
}

}; // namespace popsift

