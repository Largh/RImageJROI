## This file is based on the ImageJ RoiDecoder class at:
## http://imagej.nih.gov/ij/developer/source/ij/io/RoiDecoder.java.html
## For information on how the ROIs are drawn, consult ROI methods in:
## http://imagej.nih.gov/ij/developer/source/
## 
##  ImageJ/NIH Image 64 byte ROI outline header
##     2 byte numbers are big-endian signed shorts
##     0-3     "Iout"
##     4-5     version (>=217)
##     6-7     roi type
##     8-9     top
##     10-11   left
##     12-13   bottom
##     14-15   right
##     16-17   NCoordinates
##     18-33   x1,y1,x2,y2 (straight line)
##     34-35   stroke width (v1.43i or later)
##     36-39   ShapeRoi size (type must be 1 if this value>0)
##     40-43   stroke color (v1.43i or later)
##     44-47   fill color (v1.43i or later)
##     48-49   subtype (v1.43k or later)
##     50-51   options (v1.43k or later)
##     52-52   arrow style or aspect ratio (v1.43p or later)
##     53-53   arrow head size (v1.43p or later)
##     54-55   rounded rect arc size (v1.43p or later)
##     56-59   position
##     60-63   reserved (zeros)
##     64-       x-coordinates (short), followed by y-coordinates
##
##' Read an ImageJ ROI file. This returns a structure containing the
##' ImageJ data. 
##'
##' @title Read an ImageJ ROI file
##' @param file Name of ImageJ ROI file to read
##' @param verbose Whether to report information
##' @return A structure of class \code{ijroi} containing the ROI information
##' @author David Sterratt
##' @export
##' @seealso \code{\link{plot.ijroi}} for plotting single ROI objects.
##' 
##' \code{\link{read.ijzip}} for reading several ROI objects from .zip files.
##' @examples
##' library(png)
##' path <- file.path(system.file(package = "RImageJROI"), "extdata", "ijroi")
##' im <- as.raster(readPNG(file.path(path, "imagej-logo.png")))
##' plot(NA, NA, xlim=c(0, ncol(im)), ylim=c(nrow(im), 0), asp=1) 
##' rasterImage(im, 0,  nrow(im), ncol(im), 0, interpolate=FALSE)
##' r <- read.ijroi(file.path(path, "rect.roi"))
##' plot(r, TRUE)
##' r <- read.ijroi(file.path(path, "polygon.roi"))
##' plot(r, TRUE)
##' r <- read.ijroi(file.path(path, "oval.roi"))
##' plot(r, TRUE)
##' 
read.ijroi <- function(file, verbose=FALSE) {
  ## Define internal helper functions
  getByte <- function(con) {
    pos <- seek(con) 
    n <- readBin(con, raw(0), 1, size=1)
    if (verbose)
      message(paste("Pos ", pos , ": Byte ", n, sep=""))
    return(as.integer(n))
  }

  getShort <- function(con) {
    pos <- seek(con) 
    n <- readBin(con, integer(0), 1, size=2, signed=TRUE, endian="big")
    if (n < -5000) {
      seek(con, -2, origin="current")
      n <- readBin(con, integer(0), 1, size=2, signed=FALSE, endian="big")
    }
    if (verbose)
      message(paste("Pos ", pos , ": Short ", n, sep=""))
    return(n)
  }
  
  getInt <- function(con)  {
    pos <- seek(con) 
    n <- readBin(con, integer(0), 1, size=4, signed=TRUE, endian="little")
    if (verbose)
      message(paste("Pos ", pos , ": Integer ", n, sep=""))
    return (n);
  }

  getFloat <- function(con)  {
    pos <- seek(con) 
    n <- readBin(con, double(0), 1, size=4, signed=TRUE, endian="big")
    if (verbose)
      message(paste("Pos ", pos , ": Float ", n, sep=""))
    return (n);
  }
  
  ## subtypes
  subtypes <- list(TEXT    = 1,
                   ARROW   = 2,
                   ELLIPSE = 3,
                   IMAGE   = 4)

  ## options
  opts <- list(SPLINE_FIT    = as.raw(1),
               DOUBLE_HEADED = as.raw(2),
               OUTLINE       = as.raw(4))
  
  ## types
  types <- list(polygon  = 0,
                rect     = 1,
                oval     = 2,
                line     = 3,
                freeline = 4,
                polyline = 5,
                noRoi    = 6,
                freehand = 7,
                traced   = 8,
                angle    = 9,
                point    = 10)

  ## Main code
  name <- NULL
  if (!is.null(file)) {
    size <- file.info(file)$size
    if (!grepl(".roi$", file) && size>5242880)
      stop("This is not an ROI or file size>5MB)")
    name <- basename(file)
  }
  
  ## Open the connection
  con <- file(file, "rb")

  ## Test that it's the right kind of file
  if (getByte(con) != 73 || getByte(con) != 111) {  ## "Iout"
    stop("This is not an ImageJ ROI");
  }

  if (verbose)
    message("Reading format data")
  
  ## Create place to store data
  r <- list()

  ## Get the data. This all has to be in the order corresponding to the
  ## positions mentioned at the top of the file
  getShort(con)                         # Unused
  r$version <-      getShort(con)
  r$type <-         getByte(con)
  getByte(con)                          # Unused
  r$top <-          getShort(con)       # TOP
  r$left <-         getShort(con)       # LEFT
  r$bottom <-       getShort(con)       # Bottom
  r$right <-        getShort(con)       # RIGHT
  r$width <-    with(r, right-left)
  r$height <-   with(r, bottom-top)
  r$n <-            getShort(con)       # N_COORDINATES
  r$x1 <-           getFloat(con)     
  r$y1 <-           getFloat(con)     
  r$x2 <-           getFloat(con)     
  r$y2 <-           getFloat(con)
  r$strokeWidth <-  getShort(con)       # STROKE_WIDTH
  r$shapeRoiSize <- getInt(con)         # SHAPE_ROI_SIZE
  r$strokeColor <-  getInt(con)
  r$fillColor <-    getInt(con)
  r$subtype <-      getShort(con)       # SUBTYPE
  if(r$type %in% types["line"] & !r$subtype %in% subtypes["ARROW"]) {
    r$options <- NA
  } else {
    r$options < as.raw(getShort(con))
  }     # OPTIONS
  if ((r$type == types["freehand"]) && (r$subtype == subtypes["ELLIPSE"])) {
    r$aspectRatio <- getFloat(con)      # ELLIPSE_ASPECT_RATIO
  } else {
    r$style <-      getByte(con)        # ARROW_STYLE
    r$headSize <-   getByte(con)        # ARROW_HEAD_SIZE    
    r$arcSize <-    getShort(con)       # ROUNDED_RECT_ARC_SIZE
  }
  r$position <-     getInt(con)         # POSITION
  getShort(con)                         # Unused
  getShort(con)                         # Unused

  if (verbose)
    message("Reading coordinate data")
  
  if (!is.null(name) && (grepl(".roi$", name)))
    r$name <- substring(name, 1, nchar(name) - 4)
    
  isComposite <- (r$shapeRoiSize >0);
  if (isComposite) {
    stop("Composite ROIs not supported")
    ## roi = getShapeRoi();
    ## if (version>=218) getStrokeWidthAndColor(roi);
    ##          roi.setPosition(position);
    ## return roi;
  }
  ## if (r$type %in% types[c("rect")]) {

  ## if (r$type %in% types[c("oval")]) {

  if (r$type %in% types["line"]) {
    if (r$subtype %in% types["ARROW"]) {
      r$doubleHeaded <- (r$options & opts$DOUBLE_HEADED) !=0
      r$outline <- (r$options & opts$OUTLINE) !=0
      ##                     if (style>=Arrow.FILLED && style<=Arrow.OPEN)
      ##                         ((Arrow)roi).setStyle(style);

      ##                     if (headSize>=0 && style<=30)
      ##                         ((Arrow)roi).setHeadSize(headSize);
      ##                 } else
      ##                     roi = new Line(x1, y1, x2, y2);
    }
  }

  ## Read in coordinates
  if (r$type %in% types[c("polygon", "freehand", "traced", "polyline", "freeline", "angle", "point")]) {
    r$coords <- matrix(NA, r$n, 2)
    if (r$n > 0) {
      for (i in 1:r$n) {
        r$coords[i, 1] <- getShort(con)
      }
      for (i in 1:r$n) {
        r$coords[i, 2] <- getShort(con)
      }
      r$coords[r$coords<0] <- 0
      r$coords[,1] <- r$coords[,1] + r$left
      r$coords[,2] <- r$coords[,2] + r$top
    }
  }
  
  ## Generate coordinates for r$type == line
  if (r$type %in% types["line"]){
    r$coords <- matrix(NA, 2, 2)
    r$coords[1,1] <- r$x1
    r$coords[2,1] <- r$x2
    r$coords[1,2] <- r$y1
    r$coords[2,2] <- r$y2
  }
  
  r$strType <- names(types)[which(types==r$type)]
  if(r$subtype == 1) r$strSubtype <- names(subtypes)[which(subtypes==r$subtype)]
  if(r$subtype == 2) r$strSubtype <- names(subtypes)[which(subtypes==r$subtype)]
  if(r$subtype == 3) r$strSubtype <- names(subtypes)[which(subtypes==r$subtype)]
  r$types <- types
  
  ## Add range to ease plotting
  if(r$type == r$types[["oval"]] | r$type == r$types[["rect"]]) {
        r$xrange <- range(c(r$left, r$right))} else {
        r$xrange <- range(r$coords[,1])}
  if(r$type == r$types[["oval"]] | r$type == r$types[["rect"]]) {
        r$yrange <- range(c(r$top, r$bottom))} else {
        r$yrange <- range(r$coords[,2])}
  
  close(con)
  class(r) <- "ijroi"
  return(r)
}

## Demo
## demo.roi <- function() {
##   im <- as.raster(readPNG("~/image.png"))
##   plot(NA, NA, xlim=c(0, ncol(im)), ylim=c(nrow(im), 0), asp=1) 
##   rasterImage(im, 0,  nrow(im), ncol(im), 0)
##   r <- read.roi("~/image.roi")
##   plot(r, TRUE, col="cyan")
##   return(r)
## }

## ##                         if (subtype==ELLIPSE) {
## ##                             double ex1 = getFloat(X1);      
## ##                             double ey1 = getFloat(Y1);      
## ##                             double ex2 = getFloat(X2);      
## ##                             double ey2 = getFloat(Y2);

## ##                             roi = new EllipseRoi(ex1,ey1,ex2,ey2,aspectRatio);
## ##                             break;
## ##                         }
## ##             default:
## ##                 throw new IOException("Unrecognized ROI type: "+type);
## ##         }
## ##         if (name!=null) roi.setName(name);
        
## ##         // read stroke width, stroke color and fill color (1.43i or later)
## ##         if (version>=218) {
## ##             getStrokeWidthAndColor(roi);
## ##             boolean splineFit = (options&SPLINE_FIT)!=0;
## ##             if (splineFit && roi instanceof PolygonRoi)
## ##                 ((PolygonRoi)roi).fitSpline();
## ##         }
        
## ##         if (version>=218 && subtype==TEXT)
## ##             roi = getTextRoi(roi);

## ##         roi.setPosition(position);
## ##         return roi;
## ##     }

## ## }

## ##     void getStrokeWidthAndColor(Roi roi) {
## ##         if (strokeWidth>0)
## ##             roi.setStrokeWidth(strokeWidth);
## ##         if (strokeColor!=0) {
## ##             int alpha = (strokeColor>>24)&0xff;
## ##             roi.setStrokeColor(new Color(strokeColor, alpha!=255));
## ##         }

## ##         if (fillColor!=0) {
## ##             int alpha = (fillColor>>24)&0xff;
## ##             roi.setFillColor(new Color(fillColor, alpha!=255));
## ##         }
## ##     }
    
## ##     Roi getTextRoi(Roi roi) {
## ##         Rectangle r = roi.getBounds();
## ##         int hdrSize = RoiEncoder.HEADER_SIZE;
## ##         int size = getInt(hdrSize);
## ##         int style = getInt(hdrSize+4);
## ##         int nameLength = getInt(hdrSize+8);
## ##         int textLength = getInt(hdrSize+12);
## ##         char[] name = new char[nameLength];
## ##         char[] text = new char[textLength];
## ##         for (int i=0; i<nameLength; i++)
## ##             name[i] = (char)getShort(hdrSize+16+i*2);
## ##         for (int i=0; i<textLength; i++)
## ##             text[i] = (char)getShort(hdrSize+16+nameLength*2+i*2);
## ##         Font font = new Font(new String(name), style, size);
## ##         Roi roi2 = new TextRoi(r.x, r.y, new String(text), font);
## ##         roi2.setStrokeColor(roi.getStrokeColor());
## ##         roi2.setFillColor(roi.getFillColor());
## ##         return roi2;
## ##     }
