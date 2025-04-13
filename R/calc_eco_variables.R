#' Calculate common metrics of spatial distribution
#'
#' Calculate occurrence count, centroid coordinates, latitudinal range
#' (degrees), great circle distance (km), mean pairwise distance (km), and
#' summed minimum spanning tree length (km) for spatial point coordinates.
#'
#' Coordinates and their distances are computed with respect to the original
#' coordinate reference system if supplied, except in calculation of latitudinal
#' range, for which projected coordinates are transformed to geodetic ones.
#' If `crs` is unspecified, by default points are assumed to be given in
#' latitude-longitude and distances are calculated with spherical geometry.
#'
#' Duplicate coordinates will be removed. If a single unique point is supplied,
#' all distance measures returned will be `NA`.
#'
#' @param coords 2-column `data.frame` or `matrix` containing
#' x- and y-coordinates, respectively (e.g. longitude and latitude).
#' @inheritParams bandit
#'
#' @returns A 1-row, 7-column `matrix`
#'
#' @examples
#' # generate 20 occurrences for a pseudo-species
#' # centred on Yellowstone National Park (latitude-longitude)
#' # normally distributed with a standard deviation ~110 km
#' set.seed(2)
#' x <- rnorm(20, 110.5885, 2)
#' y <- rnorm(20,  44.4280, 1)
#' pts <- cbind(x,y)
#'
#' rangeSize(pts)
#'
#' @export

rangeSize <- function(coords, crs = 'epsg:4326'){
  coords <- unique(coords)
  if ( !isa(coords, 'data.frame') ){
    coords <- as.data.frame(coords)
  }
  if (nrow(coords) == 1){
    out <- cbind('nLoc' = 1,
                 'centroidX' = coords[, 1],
                 'centroidY' = coords[, 2],
                 'latRange' = NA,
                 'greatCircDist' = NA,
                 'meanPairDist' = NA,
                 'minSpanTree' = NA
    )
  } else {
    n <- nrow(coords)
    sfPts <- sf::st_as_sf(coords, coords = 1:2, crs = crs)
    if ( ! sf::st_is_longlat(sfPts)){
      coords <- sf::sf_project(from = crs, to = 'epsg:4326', coords,
                               keep = TRUE, warn = TRUE)
    }
    latDiff <- max(coords[,2]) - min(coords[,2])
    latRng <- abs(latDiff)

    # calculate all other spatial positions/distances w.r.t. original CRS
    ptsGrp <- sf::st_union(sfPts)
    # duplicate points (multiple taxa per site) don't affect centroid
    cntr <- unlist( sf::st_centroid(ptsGrp) )
    gcdists <- sf::st_distance(sfPts) # returns units-class object
    gcdists <- units::drop_units(units::set_units(gcdists, 'km'))
    gcMax <- max(gcdists)
    mst <- vegan::spantree(gcdists)
    agg <- sum(mst$dist)
    diag(gcdists) <- NA
    mpd <- mean(gcdists, na.rm = TRUE)
    out <- cbind('nLoc' = n,
                 'centroidX' = cntr[1],
                 'centroidY' = cntr[2],
                 'latRange' = latRng,
                 'greatCircDist' = gcMax,
                 'meanPairDist' = mpd,
                 'minSpanTree' = agg
    )
  } # end case for >1 spatial point
  return(out)
}

#' Calculate basic spatial coverage and diversity metrics
#'
#' Summarise the geographic scope and position of occurrence data, and
#' optionally estimate diversity and evenness
#'
#' \code{sdSumry()} compiles metadata about a sample or list of samples,
#' before or after spatial subsampling. The function counts the number
#' of collections (if requested), taxon presences (excluding repeat incidences
#' of a taxon at a given site), and unique spatial sites;
#' it also calculates site centroid coordinates, latitudinal range (degrees),
#' great circle distance (km), mean pairwise distance (km), and summed
#' minimum spanning tree length (km).
#' Coordinates and their distances are computed with respect to the original
#' coordinate reference system if supplied, except in calculation of latitudinal
#' range, for which projected coordinates are transformed to geodetic ones.
#' If `crs` is unspecified, by default points are assumed to be given in
#' latitude-longitude and distances are calculated with spherical geometry.
#'
#' The first two diversity variables returned are the raw count of observed taxa
#' and the Summed Common species/taxon Occurrence Rate (SCOR). SCOR reflects
#' the degree to which taxa are common/widespread and is decoupled from
#' richness or abundance (Hannisdal *et al.* 2012). SCOR is calculated as the
#' sum across taxa of the log probability of incidence, \eqn{\lambda}.
#' For a given taxon, \eqn{\lambda = -ln(1 - p)},
#' where \eqn{p} is estimated as the fraction of occupied sites.
#' Very widespread taxa make a large contribution to an assemblage SCOR,
#' while rare taxa have relatively little influence.
#'
#' If \code{quotaQ} is supplied, `sdSumry()` rarefies richness at the
#' given coverage value and returns the point estimate of richness (Hill number 0)
#' and its 95% confidence interval, as well as estimates of evenness (Pielou's J)
#' and frequency-distribution sample coverage (given by `iNEXT$DataInfo`).
#' If \code{quotaN} is supplied, `sdSumry()` rarefies richness to the given
#' number of occurrence counts and returns the point estimate of richness
#' and its 95% confidence interval.
#' Coverage-based and classical rarefaction are both calculated with
#' [iNEXT::estimateD()] internally. For details, such as how diversity
#' is extrapolated if sample coverage is insufficient to achieve a specified
#' rarefaction level, consult Chao and Jost (2012) and Hsieh *et al.* (2016).
#'
#' @inheritParams cookies
#' @param dat A \code{data.frame} or \code{matrix} containing taxon names,
#' coordinates, and any associated variables; or a list of such structures.
#' @param taxVar The name or numeric position of the column containing
#' taxonomic identifications. `taxVar` must be of same class as `xy`, e.g. a
#' numeric column position if `xy` is given as a vector of numeric positions.
#' @param collections The name or numeric position of the column containing
#' unique collection IDs, e.g. 'collection_no' in PBDB data downloads.
#' @param quotaQ A numeric value for the coverage (quorum) level at which to
#' perform coverage-based rarefaction (shareholder quorum subsampling).
#' @param quotaN A numeric value for the quota of taxon occurrences to subsample
#' in classical rarefaction.
#' @param omitDom If \code{omitDom = TRUE} and \code{quotaQ} or \code{quotaN}
#' is supplied, remove the most common taxon prior to rarefaction. The `nTax`
#' and `evenness` returned are unaffected.
#'
#' @returns A `matrix` of spatial and optional diversity metrics. If `dat` is a
#' `list` of `data.frame` objects, output rows correspond to input elements.
#'
#' @examples
#' # generate occurrences
#' set.seed(9)
#' x  <- sample(rep(1:5, 10))
#' y  <- sample(rep(1:5, 10))
#' # make some species 2x or 4x as common
#' abund <- c(rep(4, 5), rep(2, 5), rep(1, 10))
#' sp <- sample(letters[1:20], 50, replace = TRUE, prob = abund)
#' obs <- data.frame(x, y, sp)
#'
#' # minimum sample data returned
#' sdSumry(obs, c('x','y'), 'sp')
#'
#' # also calculate evenness and coverage-based rarefaction diversity estimates
#' sdSumry(obs, xy = c('x','y'), taxVar = 'sp', quotaQ = 0.7)
#'
#' @seealso [rangeSize()]
#'
#' @export
#'
#' @references
#'
#' \insertRef{Chao2012}{divvy}
#'
#' \insertRef{Hannisdal2012}{divvy}
#'
#' \insertRef{Hsieh2016}{divvy}

sdSumry <- function(dat, xy, taxVar,
                    crs = 'epsg:4326', collections = NULL,
                    quotaQ = NULL, quotaN = NULL,
                    omitDom = FALSE){
  dfsumry <- function(df){
    out <- c()
    # n. collections (PBDB data) may be useful to know if rarefying
    if ( !is.null(collections) ){
      collSamp <- unique( df[,collections] )
      out <- cbind(out, 'nColl' = length(collSamp))
    }
    # comb out any duplicate occurrences of a taxon w/in single site.
    # do this after counting collections in case a single taxon
    # at a single site is recorded in multiple collections
    df <- uniqify(df, taxVar = taxVar, xy = xy)
    nOcc <- nrow(df)

    # run range size fcn as if all occs were from a single taxon
    locs <- unique( df[,xy] )
    nSite <- nrow(locs)
    spatSumry <- rangeSize(coords = locs, crs = crs)
    out <- cbind(out, 'nOcc' = nOcc, spatSumry)

    # SCOR summed common occurrence rate (Hannisdal 2012)
    freqs <- table( df[,taxVar] )
    freqOrdr <- sort( as.numeric(freqs), decreasing = TRUE)
    # rate probability of detection under Poisson
    lambda <- -log(1 - freqOrdr/nSite) # natural log
    scor <- sum(lambda)

    # diversity metrics; optional coverage and/or classical rarefaction
    taxSamp <-  unique( df[,taxVar] )
    s <- length(taxSamp)
    out <- cbind(out, 'SCOR' = scor, 'nTax' = s) # raw count of taxa

    # Pielou's J evenness metric (calculate before omitting dom)
    pTax <- freqOrdr / sum(freqOrdr)
    h <- -sum(pTax * log(pTax))
    # vegan::diversity('shannon', base = exp(1))
    j <- h / log(s)

    if (omitDom == TRUE){
      freqOrdr <- freqOrdr[-1]
    }
    if ( !is.null(quotaQ) ){
      sqsInfo <-  iNEXT::iNEXT(list( c(nSite, freqOrdr) ),
                               datatype = 'incidence_freq')
      u <- sqsInfo$DataInfo$SC
      sqsFull <- iNEXT::estimateD(list( c(nSite, freqOrdr) ),
                                  datatype = 'incidence_freq',
                                  base = 'coverage', level = quotaQ
                                  # conf=NULL # 95% CI or none
                                  )
      # q0 = richness, q1 = exp of Shannon's entropy index,
      # q2 = inverse of Simpson's concentration index
      sqsRich <- sqsFull[sqsFull$Order.q == 0, c('qD','qD.LCL','qD.UCL')]
      names(sqsRich) <- c('SQSdiv','SQSlow95','SQSupr95')
      # return sample coverage, richness estimate and 95% CI
      out <- cbind(out, 'evenness' = j, 'coverage' = u, sqsRich)
    }
    if ( !is.null(quotaN) ){
      crFull <- iNEXT::estimateD(list( c(nSite, freqOrdr) ),
                                 datatype = 'incidence_freq',
                                 base = 'size', level = quotaN # , conf=NULL # 95% CI or none
                                 )
      crRich <- crFull[crFull$Order.q == 0, c('qD','qD.LCL','qD.UCL')]
      names(crRich) <- c('CRdiv','CRlow95','CRupr95')
      out <- cbind(out, crRich)
    }
    out
  }
  if ( isa(dat, 'list') ){
    finL <- lapply(dat, dfsumry)
    fin <- data.frame(do.call(rbind, finL))
    # if original list has named elements e.g. latitudinal bands - keep them
    if ( ! is.null(names(dat)) ){
      fin$id <- names(dat)
    }
  }
  if (class(dat) %in% c('matrix', 'data.frame')){
    fin <- dfsumry(dat)
  }
  return(fin)
}
