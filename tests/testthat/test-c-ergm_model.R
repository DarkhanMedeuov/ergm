#  File tests/testthat/test-c-ergm_model.R in package ergm, part of the Statnet suite
#  of packages for network analysis, https://statnet.org .
#
#  This software is distributed under the GPL-3 license.  It is free,
#  open source, and has the attribution requirements (GPL Section 7) at
#  https://statnet.org/attribution
#
#  Copyright 2003-2019 Statnet Commons
#######################################################################
context("test-c-ergm_model.R")

data(florentine)

test_that("concatenation of ergm_models works", {
  ergm_model(~edges+offset(kstar(2))+absdiff("priorates")+gwesp(0,fixed=FALSE)+triangles+offset(gwdsp(0,fixed=FALSE))+absdiff("wealth"),flobusiness) -> m12
  ergm_model(~edges+offset(kstar(2))+absdiff("priorates")+gwesp(0,fixed=FALSE),flobusiness) -> m1
  ergm_model(~triangles+offset(gwdsp(0,fixed=FALSE))+absdiff("wealth"),flobusiness) -> m2
  expect_equal(c(m1,m2),m12)
})
