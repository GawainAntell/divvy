# TODO option to pass on prj info to relevant function guts

# return vector of cells that lie within buffer radius of given seed
# internal fcn for findPool and cookie
findPool <- function(seed, dat, siteId, xy, r, nSite # , prj
                     ){
  seedRow <- which(dat[, siteId] == seed)[1]
  # make sure coords are a 2-col, not-dataframe-class object to give to sf
  seedxy <- as.matrix( dat[seedRow, xy] )
  seedpt <- sf::st_point(seedxy)
  # make sure to hard code the CRS for the buffer; sf can't infer lat-long
  seedsfc <- sf::st_sfc(seedpt, crs = 'epsg:4326')
  buf <- sf::st_buffer(seedsfc, dist = r*1000)
  # split poly into multipolygon around antimeridian (patches 2020 bug)
  bufWrap <- sf::st_wrap_dateline(buf, options = c("WRAPDATELINE=YES"))
  # identical results if st_union() applied to bufWrap.
  # alternative way to construct buffer, but adding new pkg dependency:
  # rangemap::geobuffer_points(seedxy, r*1000, wrap_antimeridian = TRUE)

  # find sites within radius of seed site/cell
  datSf <- sf::st_as_sf(dat, coords = xy, crs = 'epsg:4326')
  poolBool <-  sf::st_intersects(datSf, bufWrap, sparse = FALSE)
  pool <- dat[poolBool, siteId]
  return(pool)
}

# function to try all possible starting pts (i.e. all occupied cells)
# save the ID of any cells that contain given pool size within buffer
findSeeds <- function(dat, siteId, xy, r, nSite # , prj
                      ){
  # count unique sites (not taxon occurences) relative to subsample quota
  # dupes <- duplicated(dat[,siteId]) # can leave out since in higher-nested fn
  # dat <- dat[ !dupes, ]

  # test whether each occupied site/cell is viable for subsampling
  posSeeds <- dat[,siteId]
  posPools <- sapply(posSeeds, function(s){
    sPool <- findPool(s, dat, siteId, xy, r, nSite)
    n <- length(sPool)
    if (n >= nSite)
      sPool
  })
  # return pool site/cell IDs for each viable seed point
  # same overall list structure as cookies outputs; names = seed IDs
  Filter(Negate(is.null), posPools)
  # posPools[!sapply(posPools, is.null)] # equivalent, base syntax

}


#' Rarefy localities within circular regions of standard area
#'
#' Spatially subsample a dataset to produce samples of standard area and extent.
#'
#' The function takes a single location as a starting (seed) point and
#' circumscribes a buffer of \code{r} km around it. Buffer circles that span
#' the antemeridian (180 deg longitude) are wrapped as a multipolygon
#' to prevent artificial truncation. After standardising radial extent, sites
#' are drawn within the circular extent until a quota of \code{nSite}.
#' Sites are sampled without replacement, so a location is only used as a seed
#' point if it is within \code{r} km distance of at least \code{nSite} locations.
#'
#' The probability of drawing each site within the standardised extent is
#' either equal (\code{weight = FALSE}) or proportional to the inverse-square
#' of its distance from the seed point (\code{weight = TRUE}), which clusters
#' subsample locations more tightly.
#'
#' The method is introduced in Antell et al. (2020) and described in
#' detail in Methods S1 therein.
#'
#' @inheritParams clustr
#' @param siteId The name or numeric position of the column in \code{dat}
#' containing codes for unique spatial sites, e.g. raster cell names/positions.
#' @param xy A vector of two elements, specifying the name or numeric position
#' of the columns in \code{dat} containing longitude and latitude coordinates.
#' Coordinates for the same site ID should be identical, and where IDs are
#' raster cells the coordinates are usually expected to be cell centroids.
#' @param r Numeric value for the radius (km) defining the circular extent
#' of each spatial subsample.
#' @param weight Whether sites within the subsample radius should be drawn
#' at random (\code{weight = FALSE}) or with probability inversely proportional
#' to the square of their distance from the centre of the subsample region.
#'
#' @seealso [clustr()]
#' @export
cookies <- function(dat, siteId, xy, r, nSite, # prj,
                    iter, weight = FALSE, output = 'locs'){
  dupes <- duplicated(dat[,siteId])
  coords <- dat[ !dupes, c(xy, siteId)]

  # this is the rate-limiting step (v slow), but overall
  # it's most efficient to construct all spatial buffers here at start
  # and not repeat the calculations anywhere later!
  allPools <- findSeeds(coords, siteId, xy, r, nSite)
  if (length(allPools) < 1){
    stop('not enough close sites for any sample')
  }
  # convert to spatial features for distance calculations later
  if (weight){
    datSf <- sf::st_as_sf(coords, coords = xy, crs = 'epsg:4326')
  }

  # takes a subsample of sites/cells, w/o replacement, w/in buffered radius
  cookie <- function(){
    # select one seed cell at random
    seeds <- names(allPools)
    if (length(seeds) > 1){
      seed <- sample(sample(seeds), 1)
    } else {
      # sample() fcn makes mistake if only 1 item to pick
      seed <- seeds
    }
    pool <- allPools[seed][[1]]

    if (weight){
      # remove seed from probabilistic sampling - include it manually
      # (otherwise inverse distance will divide by zero)
      pool <- pool[ !pool == seed]
      poolBool <- coords[,siteId] %in% pool
      poolPts <- datSf[poolBool,]

      # squared inverse weight because inverse alone is too weak an effect
      seedRow <- which(coords[, siteId] == seed)[1]
      seedPt <- datSf[seedRow,]
      gcdists <- sf::st_distance(poolPts, seedPt) # spherical distances by default
      wts <- sapply(gcdists, function(x) x^(-2))
      # sample() doesn't require wts sum = 1; identical results without rescaling
      samplIds <- c(seed,
                    sample(sample(pool), nSite-1, prob = wts, replace = FALSE)
      )
    } else {
      samplIds <- sample(sample(pool), nSite, replace = FALSE)
    } # end site rarefaction
    if (output == 'full'){
      inSamp <- match(dat[, siteId], samplIds)
      out <- dat[!is.na(inSamp), ]
    } else {
      if (output == 'locs'){
        inSamp <- match(samplIds, coords[, siteId])
        out <- coords[inSamp, xy]
      } else {
        stop('output argument must be one of c(\'full\', \'locs\')')
      }
    } # end output formatting
    return(out)
  }
  replicate(iter, cookie(), simplify = FALSE)
}