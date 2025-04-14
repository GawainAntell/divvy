# divvy 1.0.1

## Bug fixes

* Advanced the minimum version numbers required for `R` and `units` 
* Fixed specification of `units` in objects for compatibility with `cbind`

# divvy 1.0.0

## Breaking changes

* Changed function names `rangeSizer` to `rangeSize` and `sdsumry` to `sdSumry`
* Removed `siteId` argument from `cookies` and `uniqify`
* More convenient argument order in `sdSumry` and `uniqify`

## Bug fixes

* Fixed CRS mistakes in examples for `bandit` and `classRast` documentation
* Updated URL addresses in vignettes

## Improvements

* Built pkgdown website
* Created unit tests
* Added detail to function help documentation
* Updated examples to avoid calling deprecated spatial packages

# version 0.2.0

## New

* Added second vignette, with complementary example uses of `divvy` functions

## Improvements

* Expanded README with additional overview information and code examples

# version 0.1.1

## Bug fixes

* Patched bugs in `sdsumry` from breaking changes in `iNEXT` returned objects
* Updated argument specifications for compatibility with latest version of `sf`
* Adapted for the edge case of equally-spaced occurrences

## Improvements

* Added a `NEWS.md` file to track changes to the package
* Added examples to function documentation
* Specified all returned values
