\name{read.ijzip}
\alias{read.ijzip}
\title{Read ImageJ zip file containing several ROI files}
\usage{
read.ijzip(file, names = TRUE, list.files = FALSE, print.all = FALSE,
  verbose = FALSE)
}
\arguments{
  \item{file}{zip file containing a collection of ImageJ
  ROI files}

  \item{names}{Logical, indicating whether the ROI file
  names should be used as names for the elements in the
  list (see Return). If FALSE a sequence of names
  specifying the type of ROI is automatically generated.}

  \item{list.files}{logical, indicating whether a
  data.frame of ROI files in \code{file} should be returned
  instead of a list of results. Defaults to FALSE. If TRUE
  equals to \code{unzip(file, list = TRUE)}.}

  \item{print.all}{logical indicating whether to print all
  information from \code{\link{read.ijroi}} function as
  opposed to a subset of relevant information? Defaults to
  \code{FALSE}.}

  \item{verbose}{Whether to report information (see
  \code{\link{read.ijroi}}).}
}
\value{
An object of class \code{ijzip} containing a list of the
coordinates and types of ImageJ ROIs. Each element is named
after option specified in \code{names}.
}
\description{
A wrapper function, which reads a zip file containing
ImageJ ROI files using \code{\link{read.ijroi}} function.
}
\examples{
file <- file.path(system.file(package = "RImageJROI"), "extdata", "ijroi", "ijzip.zip")
x <- read.ijzip(file)
plot(x)
}
\author{
Mikko Vihtakari
}
\seealso{
\code{\link{read.ijroi}}, \code{\link{plot.ijzip}}.
}

