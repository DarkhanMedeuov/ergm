#  File R/ergm.pl.R in package ergm, part of the Statnet suite
#  of packages for network analysis, https://statnet.org .
#
#  This software is distributed under the GPL-3 license.  It is free,
#  open source, and has the attribution requirements (GPL Section 7) at
#  https://statnet.org/attribution
#
#  Copyright 2003-2019 Statnet Commons
#######################################################################

#' @rdname ergm.mple
#' @description \code{ergm.pl} is an even more internal workhorse
#'   function that prepares many of the components needed by
#'   \code{ergm.mple} for the regression rountines that are used to
#'   find the MPLE estimated ergm. It should not be called directly by
#'   the user.
#' @param theta.offset a logical vector specifying which of the model
#'   coefficients are offset, i.e. fixed
#' @return \code{ergm.pl} returns a list containing: \itemize{ \item
#'   xmat : the compressed and possibly sampled matrix of change
#'   statistics
#' \item zy : the corresponding vector of responses,
#'   i.e. tie values
#' \item foffset : ??
#' \item wend : the vector of
#'   weights for 'xmat' and 'zy'
#' \item numobs : the number of dyads
#'  
#' \item
#'   theta.offset : a numeric vector whose ith entry tells whether the
#'   the ith curved coefficient?? was offset/fixed; -Inf implies the
#'   coefficient was fixed, 0 otherwise; if the model hasn't any
#'   curved terms, the first entry of this vector is one of
#'   log(Clist$nedges/(Clist$ndyads-Clist$nedges))
#'   log(1/(Clist$ndyads-1)) depending on 'Clist$nedges' }
#' @keywords internal
#' @export
ergm.pl<-function(nw, fd, m, theta.offset=NULL,
                  control,
                  verbose=FALSE) {
  Clist <- ergm.Cprepare(nw, m)
  bip <- Clist$bipartite
  n <- Clist$n
  d <- sum(fd)
  el <- as.edgelist(NVL(cbind(Clist$tails, Clist$heads), matrix(,0,2)), n, directed=TRUE, bipartite=FALSE, loops=TRUE) # This will be filtered by fd anyway.
  elfd <- as.rlebdm(el) & fd
  e <- sum(elfd)

  maxNumDyadTypes <- min(if(is.function(control$MPLE.max.dyad.types)) control$MPLE.max.dyad.types(d=d, e=e) else control$MPLE.max.dyad.types,
                         d)
  maxDyads <- if(is.function(control$MPLE.samplesize)) control$MPLE.samplesize(d=d, e=e) else control$MPLE.samplesize

  z <- .C("MPLE_wrapper",
          as.integer(Clist$tails), as.integer(Clist$heads),
          as.integer(Clist$nedges),
          as.double(to_ergm_Cdouble(fd)),
          as.integer(n), 
          as.integer(Clist$dir),     as.integer(bip),
          as.integer(Clist$nterms), 
          as.character(Clist$fnamestring), as.character(Clist$snamestring),
          as.double(Clist$inputs),
          y = integer(maxNumDyadTypes),
          x = double(maxNumDyadTypes*Clist$nstats),
          weightsvector = integer(maxNumDyadTypes),
          as.integer(maxDyads),
          as.integer(maxNumDyadTypes),
          PACKAGE="ergm")
  uvals <- z$weightsvector!=0
  if (verbose) {
    message(paste("MPLE covariate matrix has", sum(uvals), "rows."))
  }
  zy <- z$y[uvals]
  wend <- as.numeric(z$weightsvector[uvals])
  xmat <- matrix(z$x, ncol=Clist$nstats, byrow=TRUE)[uvals,,drop=FALSE]
  colnames(xmat) <- param_names(m,canonical=TRUE)
  rm(z,uvals)

  # If we ran out of space, AND we have a sparse network, then, use
  # case-control MPLE.
  if(sum(wend)<d && mean(zy)<1/2){
    if(verbose) message("A sparse network with too many unique dyads encountered. Using case-control MPLE.")
    # Strip out the rows associated with ties.
    wend <- wend[zy==0]
    xmat <- xmat[zy==0,,drop=FALSE]
    zy <- zy[zy==0]

    maxNumDyadTypes <- min(maxNumDyadTypes, e)

    z <- .C("MPLE_wrapper",
            as.integer(Clist$tails), as.integer(Clist$heads),
            as.integer(Clist$nedges),
            as.numeric(to_ergm_Cdouble(elfd)),
            as.integer(n), 
            as.integer(Clist$dir),     as.integer(bip),
            as.integer(Clist$nterms), 
            as.character(Clist$fnamestring), as.character(Clist$snamestring),
            as.double(Clist$inputs),
            y = integer(maxNumDyadTypes),
            x = double(maxNumDyadTypes*Clist$nstats),
            weightsvector = integer(maxNumDyadTypes),
            as.integer(.Machine$integer.max), # maxDyads
            as.integer(maxNumDyadTypes),
            PACKAGE="ergm")
    uvals <- z$weightsvector!=0
    zy.e <- z$y[uvals]
    wend.e <- as.numeric(z$weightsvector[uvals])
    xmat.e <- matrix(z$x, ncol=Clist$nstats, byrow=TRUE)[uvals,,drop=FALSE]
    colnames(xmat.e) <- param_names(m,canonical=TRUE)
    rm(z,uvals)

    # Divvy up the sampling weight of the ties:
    wend.e <- wend.e / sum(wend.e) * e

    # Divvy up the sampling weight of the nonties:
    wend <- wend / sum(wend) * (d-e)

    zy <- c(zy,zy.e)
    wend <- c(wend, wend.e)
    xmat <- rbind(xmat, xmat.e)

    rm(zy.e, wend.e, xmat.e)
  }

  #
  # Adjust for the offset
  # =======================
  # Helper function
  # A is a matrix. V is a column vector that may contain Infs
  # computes A %*% V, counting 0*Inf as 0
  # May be slow if there are many rows. Use C here?
  multiply.with.inf <- function(A,V) {
    cbind(sapply(seq_len(nrow(A)), function(i) sum(V * A[i,], na.rm=TRUE)))
  }

  if(any(m$etamap$offsettheta)){
    if(any(is.na(theta.offset[m$etamap$offsettheta]))){
      stop("Offset terms without offset coefficients specified!")
    }
    # Compute the offset's effect.
    foffset <- multiply.with.inf(xmat[,m$etamap$offsettheta,drop=FALSE], 
                                 cbind(theta.offset[m$etamap$offsettheta])) 
    
    # Remove offset covariate columns.
    xmat <- xmat[,!m$etamap$offsettheta,drop=FALSE] 
    colnames(xmat) <- param_names(m,canonical=TRUE)[!m$etamap$offsettheta]
    # Now, iff a row's offset effect is infinite, then it carries no
    # further information whatsoever, so it should be dropped.
    xmat <- xmat[is.finite(foffset),,drop=FALSE]
    zy <- zy[is.finite(foffset)]
    wend <- wend[is.finite(foffset)]
    foffset <- foffset[is.finite(foffset)]
  }else{
    foffset <- rep(0, length=length(zy))
    theta.offset <- rep(0, length=Clist$nstats)
    if(e>0){
      theta.offset[1] <- log(e/(d-e))
    }else{
      theta.offset[1] <- log(1/(d-1))
    }
    names(theta.offset) <- param_names(m,canonical=TRUE)
  }
  
  list(xmat=xmat, zy=zy, foffset=foffset, wend=wend, numobs=round(sum(wend)),
       theta.offset=theta.offset)
}
