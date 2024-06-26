setMethod("proj4string", signature(obj = "Spatial"),
	function(obj) {
                res <- as.character(obj@proj4string@projargs)
                res
        }
)

setMethod("wkt", signature(obj = "Spatial"),
	function(obj) {
                comm <- comment(slot(obj, "proj4string"))
		comm
        }
)


ReplProj4string = function(obj, value) {
	p4str <- value@projargs
	ll <- FALSE
	if (!is.na(p4str)) {
		res <- grep("longlat", p4str, fixed=TRUE)
		if (length(res) != 0) ll <- TRUE
	}
	if (ll) {
		bb <- bbox(obj)
                ll_sanity_res <- .ll_sanity(bb)
		if (!ll_sanity_res) {
                    lst <- sapply(attr(ll_sanity_res, "details"),
                        attr, "out")
                    out <- paste(format(unlist(lst), digits=12), collapse=" ")
                    mess <- paste("Geographical CRS given to",
                        "non-conformant data:", out)
                    if (get_ll_warn())
                        warning(mess)
                    else 
			stop(mess)
		}
	}
        if (!is.na(is.projected(obj)) && !is.na(p4str)) {
            p4s <- proj4string(obj)
            if (p4s != p4str) {
                mess <- paste("A new CRS was assigned to an object with an existing CRS:\n", p4s, "\nwithout reprojecting.\nFor reprojection, use function spTransform", sep="")
                if (get_ReplCRS_warn()) warning(mess)
            }
        }
	obj@proj4string = value;
	obj
}
setReplaceMethod("proj4string", c("Spatial", "character"), 
	function(obj, value) ReplProj4string(obj, CRS(value)))
setReplaceMethod("proj4string", c("Spatial", "CRS"), ReplProj4string)

# split out from proj4string<- and Spatial validity to cover numerical fuzz
# RSB 070216
.ll_sanity <- function(bb) {
        TOL <- get_ll_TOL()
	tol <- .Machine$double.eps ^ TOL
	W <- bb[1,1] < -180 && 
	    !isTRUE(all.equal((bb[1, 1] - -180), 0, tolerance = tol))
        if (W) attr(W, "out") <- bb[1,1]
	E <- bb[1,2] > 360 && 
	    !isTRUE(all.equal((bb[1, 2] - 360), 0, tolerance = tol))
        if (E) attr(E, "out") <- bb[1,2]
	S<- bb[2,1] < -90 && 
	    !isTRUE(all.equal((bb[2, 1] - -90), 0, tolerance = tol))
        if (S) attr(S, "out") <- bb[2,1]
	N <- bb[2,2] > 90 && 
	    !isTRUE(all.equal((bb[2, 2] - 90), 0, tolerance = tol))
        if (N) attr(N, "out") <- bb[2,2]
        res <- !(any(W || E || S || N))
        attr(res, "details") <- list(W, E, S, N)
	res
}
is.projectedSpatial <- function(obj) {
	p4str <- slot(obj, "proj4string")
	is.projected(p4str)
}

setMethod("is.projected", signature(obj = "Spatial"), is.projectedSpatial)

is.projectedCRS <- function(obj) {
	p4str <- slot(obj, "projargs")
	wkt2 <- comment(obj)
	if (is.null(wkt2) && is.na(p4str)) # fast track for default objects
	    return(NA)
	if (requireNamespace("sf", quietly = TRUE)) {
		    o <- try(sf::st_is_longlat(obj), silent=TRUE)
# rbgm workaround for +proj=utm +zone=18 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +# +a=6378137.0 +es=0.006694380022900787 +lon_0=-75d00 +lat_0=0d00 +x_0=500000.0 +y_0=0.0 +k=0.9996 in bgmfiles Final_CAM_Boxes_8.bgm
                    if (inherits(o, "try-error"))
                        length(grep("longlat", p4str, fixed = TRUE)) == 0L
                    else
                        !o
                } else {
                    if (get("startup_message", envir=.spOptions) != "none")
                        warning("Package sf not available")
                    if (!is.null(wkt2)) # and old rgdal version
		        substring(wkt2, 1, 3) != "GEO"
	            else
		        length(grep("longlat", p4str, fixed = TRUE)) == 0L
        } 
}

setMethod("is.projected", signature(obj = "CRS"), is.projectedCRS)
