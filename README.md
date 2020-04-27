<p align="center">
<img src="img/mu0_sigma0_contour2.png" width="350" title="mu sigma constraints" />
<img src="img/w0_wa_contour2.png" width="350" title="CPL constraints" />
</p>

MGCosmoMC 
===========
## Modified Growth with CosmoMC
This is the official repository for the MGCosmoMC patch. It implements the patch [MGCAMB](https://github.com/sfu-cosmo/MGCAMB) into the popular Markov Chain Monte Carlo engine [CosmoMC](https://github.com/cmbant/CosmoMC).

## Table of contents
* [1. Introduction](#1-introduction)
    * [Citing MGCosmoMC](#citing-mgcosmomc)
* [2. How to install](#2-how-to-install)
* [3. How to run](#3-how-to-run)
* [4. Installing Planck 2018 ](#4-installing-planck-2018)
* [5. DES 1YR dataset](#5-des-1yr-dataset)
    * [Aggressive cut](#aggressive-cut)
    * [Standard cut](#standard-cut)
    * [Soft cut](#soft-cut)
* [6. Derived Parameters](#derived-parameters)
* [7. Authors List](#authors-list)


## 1. Introduction
MGCosmoMC allows to set constraint on Modified Growth (MG) - Dark Energy (DE) scenarios using cosmological data. It is a patch for the popular code [CosmoMC](https://github.com/cmbant/CosmoMC), and as such it follows all the installing procedures and running procedures. We refer the reader to the [official CosmoMC webpage](http://cosmologist.info/cosmomc/) and the [ReadMe](http://cosmologist.info/cosmomc/readme.html) for the instructions.

### Citing MGCosmoMC
If you use MGCosmoMC for your scientific work, please cite the following papers:

* *MGCAMB with massive neutrinos and dynamical dark energy*   
    Alex Zucca, Levon Pogosian, Alessandra Silvestri, and Gong-Bo Zhao  
    [arXiv:1901.05956 [astro-ph.CO]](https://arxiv.org/abs/1901.05956)


* *Testing Gravity with CAMB and CosmoMC*  
Alireza Hojjati, Levon Pogosian, Gong-Bo Zhao,  
[arXiv:1106.4543 [astro-ph.CO]](https://arxiv.org/abs/1106.4543), [JCAP 1108:005,2011](http://iopscience.iop.org/article/10.1088/1475-7516/2011/08/005)


* *Searching for modified growth patterns with tomographic surveys*  
Gong-Bo Zhao, Levon Pogosian, Alessandra Silvestri, Joel Zylberberg,  
[arXiv:0809.3791 [astro-ph]](http://arxiv.org/abs/0809.3791), [Phys. Rev. D 79, 083513](https://journals.aps.org/prd/abstract/10.1103/PhysRevD.79.083513)


as well as the original CAMB [paper](http://arxiv.org/abs/astro-ph/9911177)  and CosmoMC [paper](https://arxiv.org/abs/astro-ph/0205436). The file  [``` MGCosmoMC_references.bib```](references/MGCosmoMC_references.bib) contains  all the references mentioned above.

## 2. How to install
To install MGCosmoMC simply run on your terminal:
```bash
git clone https://github.com/sfu-cosmo/MGCosmoMC
cd MGCosmoMC
make cosmomc
```
Follow these [instructions](http://cosmologist.info/cosmomc/readme.html) for a step-by-step guide to install CosmoMC.

As a general rule, if you are able to install CosmoMC, then you will be able to install MGCosmoMC.

## 3. How to run
Before running MGCosmoMC set your model parameters in [```params_CMB_MG.ini```](batch3/params_CMB_MG.ini). Pick a ``` MG_flag ``` to choose which model you are going to analyze. For a structure of the models see the [MGCAMB page](https://github.com/sfu-cosmo/MGCAMB).

```GRtrans ```  set the scale factor at which MG is switched on. We suggest to set it arger or equal than 0.001. 

Since in the MG formalism there is no prescription to build a non-linear P(k), we suggest to set the flag ``` use_nonlinear = F ```. To do so, some data requires a proper cut to eliminate the nonlinear scales. The cuts on DES 1YR dataset is described in Sect.[4](#4-des-1yr-dataset)


## 4. Installing Planck 2018
MGCosmoMC is based on CosmoMC 2017, before the Planck 2018 likelihood was released. It is still possible to use the Planck 2018 likelihood with MGCosmoMC by following the procedure illustrated in this Section.

In the following, ```/$$$``` is meant to be replaced by the path specific to your installation.
 
1. Add these lines to your ```.bashrc``` (but with your customized paths instead of` ```/$$$```):

```bash
export PYTHONPATH=/$$$/MGCosmoMC/python:$PYTHONPATH
export PLC_PATH=/$$$/Planck2018/baseline/plc_3.0/
source /$$$/Planck2018/plc_3.0/plc-3.01/bin/clik_profile.sh
```

and run

```bash
source /.bashrc
```


2. Create a symbolic link to the Planck likelihoods:

```bash
ln -s $PLC_PATH MGCosmoMC/data/clik_14.0
```

3. Now change into the MGCosmoMC directory and run ```make```
```bash
cd MGCosmoMC
make
```
4. Now you want to copy the files from the latest ```CosmoMC/batch3``` folder and the ```CosmoMC/data``` folder into the corresponding directories in MGCosmoMC. You want to keep some of the files you have in ```batch3``` (since some of them may have MG-specific alternations), but add to them the latest files.

E.g, rename your ```MGCosmoMC/batch3/common.ini``` into ```MG_common.ini```. Then, run

```bash
cp -r /$$$/CosmoMC/batch3/* /$$$/MGCosmoMC/batch3/
```
and
```bash
cp -r /$$$/CosmoMC/data/* /$$$/data/
```
and
```bash
cp -r /$$$/CosmoMC/planck_covmats/* /$$$/MGCosmoMC/planck_covmats/
```
Now go to ```/$$$/MGCosmoMC/batch3/```

and rename the ```MG_common.ini``` file back into ```common.ini```


The only difference is that in common.ini
```bash
INCLUDE(likelihood.ini)
INCLUDE(params_CMB_defaults.ini)

should be replaced by

INCLUDE(likelihood.ini)
INCLUDE(params_CMB_defaults.ini)
# MGCAMB MOD START
INCLUDE(params_CMB_MG.ini)
#MGCAMB MOD END
```

6. Now try running the standard CosmoMC test using the ```test_planck.ini``` file:

In your ```MGCosmoMC``` directory type:
```bash
cp /$$$/CosmoMC/test_planck.ini ./
```
Then, create a directory called ```chains```

```
mkdir chains
```
Then run
```
./cosmomc test_planck.ini
```
This will print some stuff on the screen, testing all the Planck likelihoods and any other likelihoods specified in the ```test_planck.ini``` and ```test.ini``` files. Then it will likely stop with some error message, e.g. 

```bash
Test likelihoods done, total logLike, chi-eq =    2103.781   4207.563
Expected likelihoods,  total logLike, chi-eq =    2625.485   5250.970
 ** Likelihoods do not match **
```
In any case, as long as it can run the Planck 2018 likelihoods, you are OK and all other procedures are the same as you would do before the update.




## 5. DES 1YR dataset

Since there is no MG counterpart of Halofit, nonlinear corrections should be turned off when using MGCosmoMC. Datasets probing nonlinear scales should be used with care and with proper cuts (to avoid nonlinear scales). For the DES 1YR dataset we provide three cuts of the nonlinear regime: soft, standard and aggressive. Choose one of them in [DES_1YR_final.dataset](data/DES/DES_1YR_final.dataset) . Also, be sure to set ```wl_use_nonlinear = F``` and ```wl_use_Weyl = T```  in [DES.ini](batch3/DES.ini).  

The weak lensing likelihood is modified to use the Weyl potential: the new implementation is in [wl.f90](source/wl.f90), while the default code is kept in [wl_std.f90](source/wl_std.f90)

The method to cut the data is described in our paper and it is based on this [DES paper](https://arxiv.org/abs/1810.02499). 

The code used to generate this cuts can be found in this [repository](https://github.com/alexzucca90/DES_linear_data)

### Aggressive Cut
The aggressive cut is obtained by setting Delta Chi^2 = 1 . The shaded regions in the plots below are removed:

<p align="center">
<img src="img/m1aggressive.png" width="350" title="aggressive cut 1" />
<img src="img/m2aggressive.png" width="350" title="aggressive cut 2" />
</p>

<p align="center">
<img src="img/m3aggressive.png" width="350" title="aggressive cut 3" />
<img src="img/m4aggressive.png" width="350" title="aggressive cut 4" />
</p>


### Standard Cut
The starndard cut is obtained by setting Delta Chi^2 = 5 . The shaded regions in the plots below are removed:

<p align="center">
<img src="img/m1standard.png" width="350" title="standard cut 1" />
<img src="img/m2standard.png" width="350" title="standard cut 2" />
</p>
<p align="center">
<img src="img/m3standard.png" width="350" title="standard cut 3" />
<img src="img/m4standard.png" width="350" title="standard cut 4" />
</p>


### Soft Cut
The soft cut is obtained by setting Delta Chi^2 = 10. The shaded regions in the plots below are removed:

<p align="center">
<img src="img/m1soft.png" width="350" title="soft cut 1" />
<img src="img/m2soft.png" width="350" title="soft cut 2" />
</p>
<p align="center">
<img src="img/m3soft.png" width="350" title="soft cut 3" />
<img src="img/m4soft.png" width="350" title="soft cut 4" />
</p>


## 6. Derived Parameters
This version has three derived parameters that depend on the *Planck parametrization* of the Mu-Gamma functions ( ```MG_flag = 1```, ```pure_MG_flag = 1```, ```mugamma_par = 2``` ). These parameters are set in [```CosmologyParametrizations_MG.f90```](source/CosmologyParametrizations_MG.f90)
```fortran
!mu_0-1
derived(15) = CMB%E11 * CMB%omv
!eta_0-1
derived(16) = CMB%E22 * CMB%omv
! sigma_0-1
derived(17) = 0.5d0 * (1.d0+CMB%E11*CMB%omv) * (2.d0+CMB%E22*CMB%omv) 
```
and [params_CMB.paramnames](paramnames/params_CMB.paramnames)
```bash
mu0m1*        \mu_0-1
gamma0m1*     \gamma_0-1
sigma0m1*     \Sigma_0-1
```
If you use a different parametrization, please modify the files accordingly.

## 7. Authors List
Main Developer:
- [Alex Zucca](https://www.sfu.ca/physics/people/profiles/azucca.html) Email: azucca@sfu.ca

Original Code Developers:
* [Gong-Bo Zhao](http://icosmology.info)
* [Alireza Hojjati](http://www.phas.ubc.ca/%7Eahojjati/index.html)
* [Levon Pogosian](http://www.sfu.ca/%7Elevon/)
* [Alessandra Silvestri](http://wwwhome.lorentz.leidenuniv.nl/%7Esilvestri/Home.html)


Repo created and maintained by [Alex Zucca](https://github.com/alexzucca90). If you find any bugs in the code, please contact Alex Zucca at azucca@sfu.ca or at azucca@dwavesys.com.

<p align="center">
<a href="http://www.sfu.ca/physics.html"><img src="https://pbs.twimg.com/profile_images/966810928669802496/LVqOwtsx_400x400.jpg" height="170px"></a>
<a href="http://www.sfu.ca/physics/cosmology/"><img src="https://avatars0.githubusercontent.com/u/7880410?s=280&v=4" height="200px"></a>
</p>
