#  File R/ergm.sufftoprob.R in package ergm, part of the Statnet suite
#  of packages for network analysis, https://statnet.org .
#
#  This software is distributed under the GPL-3 license.  It is free,
#  open source, and has the attribution requirements (GPL Section 7) at
#  https://statnet.org/attribution
#
#  Copyright 2003-2019 Statnet Commons
#######################################################################
########################################################################
# The <ergm.sufftoprob> function attaches a probability weight to each
# row of a given matrix or "mcmc" class; the resultant matrix may be 
# optionally 'compressed'
#
# --PARAMETERS--
#   suff    : a matrix, presumably the sample of sufficient statistics
#             returned by MCMC estimation
#   compress: whether the returned matrix should be compressed; in its
#             natural state 'suff' has one row for each sampled run;
#             if 'compress'=TRUE, only the unique values of the vector
#             of sufficient statistics are retained and the additional
#             column of probility weights are the proportions of MCMC 
#             runs that returned that vector (the objective is to keep
#             the size of the matrix small for very long runs to save
#             memory, speed calculations and make it easier to read);
#             default=FALSE
#   probs   : whether to treat the final column of 'suff' as weights; if
#             TRUE, the final column of 'suff' will be converted to
#             probabilities; default=FALSE
#
# --RETURNED--
#   csuff: a matrix of 'suff', compressed or not according to 'compress',
#          and  bound to a column of probability weights, which are
#          assumed to be equal before compression, unless otherwise set
#          in the last column of 'suff' and flagged by 'probs'
#
########################################################################

"ergm.sufftoprob"<- function(suff, compress=FALSE, probs=FALSE) {
  # compress argument is deprecated; it has no effect.
  cnames <- dimnames(suff)[[2]]
  if(is.null(cnames)){
    cnames <- 1:ncol(suff)
  }
  if(!is.matrix(suff)){
    csuff <- table(suff)
    csuff <- cbind(as.numeric(names(csuff)),as.numeric(csuff))
    csuff[,2] <- csuff[,2]/sum(csuff[,2])
  }else{
    if(probs){
      csuff <- suff
      csuff[,ncol(suff)] <- csuff[,ncol(suff)]/sum(csuff[,ncol(suff)])
      cnames <- cnames[-length(cnames)]
    }else{
      csuff <- cbind(suff,1/nrow(suff))
    }
  }
  dimnames(csuff) <- list(NULL, c(cnames,"prob"))
  csuff
}




