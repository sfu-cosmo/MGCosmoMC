===================
MGCosmoMC
===================
:CosmoMC:  Fortran 2008 parallelized MCMC sampler (general and cosmology)
:Homepage: http://cosmologist.info/cosmomc/

:MGCosmoMC: patch that implements `MGCAMB <https://github.com/alexzucca90/MGCAMB_tests>`_ in CosmoMC

Using MGCosmoMC
================
Run as it is a usual instance of CosmoMC. Choose the model and the parameter ranges in 
batch3/params_CMB_MG.ini (or batch2/params_CMB_MG.ini)


Description and installation
=============================

MGCosmoMC follows the same installation procedure as CosmoMC.

For full details see the `ReadMe <http://cosmologist.info/cosmomc/readme.html>`_.


DES 1YR dataset
===============
Since there is no MG counterpart of Halofit, nonlinear corrections should be turned off when using MGCosmoMC. Datasets probing nonlinear scales should be used with care and with proper cuts (to avoid nonlinear scales). For the DES 1YR dataset we provide three cuts of the nonlinear regime: soft, standard and aggressive. Choose one of them in data/DES/DES_1YR_final.dataset . Also, be sure to set wl_use_nonlinear = F and wl_use_Weyl = T in batch3/DES.ini . 


Derived Parameters
==================
This version has three derived parameters that depend on the Planck parametrization of the Mu-Gamma functions ( MG_flag = 1, pure_MG_flag = 1, mugamma_par = 2 ). If you use a different model, please modify CosmologyParametrizations_MG.f90 and paramnames/params_CM.paramnames accordingly.

.. raw:: html
    <a href="http://www.sfu.ca/physics/cosmology/"><img src="https://avatars0.githubusercontent.com/u/7880410?s=280&v=4" height="200px"></a>
    <a href="http://www.sussex.ac.uk/astronomy/"><img src="https://cdn.cosmologist.info/antony/Sussex.png" height="170px"></a>
    <a href="http://erc.europa.eu/"><img src="https://erc.europa.eu/sites/default/files/content/erc_banner-vertical.jpg" height="200px"></a>
    
