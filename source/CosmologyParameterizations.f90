    !Default parameterization using theta = r_s/D_a instead of H_0, and tau instead of z_re
    !and log(A_s) instead of A_s
    !Less general, but should give better performance
    !
    !The well-determined parameter A_s exp(-2tau) should be found by the covariance matrix
    !parameter 3 is 100*theta, parameter 4 is tau, others same as params_H except A->log(A)
    !Theta is much better constrained than H_0
    !
    !Also a background (late-time) parameterization, e.g. for use with just supernoave etc

    module CosmologyParameterizations
    use CosmologyTypes
    use CosmoTheory
    use Calculator_Cosmology
    use bbn
    implicit none
    private

    Type, extends(TCosmologyParameterization) :: ThetaParameterization
        real(mcp) :: H0_min = 40, H0_max = 100
        real(mcp) :: H0_prior_mean = 0._mcp, H0_prior_std = 0._mcp
        real(mcp) :: sterile_mphys_max = 10 !maximum allowed physical mass of thermal sterile neutrino in eV
        real(mcp) :: use_min_zre = 0._mcp
        real(mcp) :: zre_prior_mean = 0._mcp, zre_prior_std = 0._mcp
        integer :: num_derived = 0
    contains
    procedure :: ParamArrayToTheoryParams => TP_ParamArrayToTheoryParams
    procedure :: NonBaseParameterPriors => TP_NonBaseParameterPriors
    procedure :: CalcDerivedParams => TP_CalcDerivedParams
    procedure :: InitWithSetNames => TP_Init
    end type ThetaParameterization

    !Background parameters only, H0, omegam...
    Type, extends(TCosmologyParameterization) :: BackgroundParameterization
    contains
    procedure :: ParamArrayToTheoryParams => BK_ParamArrayToTheoryParams
    procedure :: CalcDerivedParams => BK_CalcDerivedParams
    procedure :: InitWithSetNames => BK_Init
    end type BackgroundParameterization

    !Late-time parameterization using more astro parameter, H0, omegab, omegam
    Type, extends(TCosmologyParameterization) :: AstroParameterization
        real(mcp) :: ombh2_prior_mean = 0._mcp, ombh2_prior_std = 0._mcp
    contains
    procedure :: ParamArrayToTheoryParams => AP_ParamArrayToTheoryParams
    procedure :: NonBaseParameterPriors => AP_NonBaseParameterPriors
    procedure :: CalcDerivedParams => AP_CalcDerivedParams
    procedure :: InitWithSetNames => AP_Init
    end type AstroParameterization

    public BackgroundParameterization,ThetaParameterization,AstroParameterization

    contains


    subroutine TP_Init(this, Ini, Names, Config)
    class(ThetaParameterization) :: this
    class(TSettingIni) :: Ini
    class(TParamNames) :: Names
    class(TGeneralConfig), target :: Config
    character(LEN=:), pointer :: prior

    call Ini%Read('H0_min',this%H0_min)
    call Ini%Read('H0_max',this%H0_max)
    call Ini%Read('use_min_zre',this%use_min_zre)
    call Ini%Read('sterile_mphys_max',this%sterile_mphys_max)
    prior => Ini%Read_String('H0_prior',NotFoundFail=.false.)
    if (prior/='') then
        read(prior,*) this%H0_prior_mean, this%H0_prior_std
    end if
    prior => Ini%Read_String('zre_prior',NotFoundFail=.false.)
    if (prior/='') then
        read(prior,*) this%zre_prior_mean, this%zre_prior_std
    end if

    call this%Initialize(Ini,Names, 'paramnames/params_CMB.paramnames', Config)
    if (CosmoSettings%bbn_consistency) call Names%Add('paramnames/derived_bbn.paramnames')
    call Names%Add('paramnames/derived_theory.paramnames')
    if (CosmoSettings%use_LSS) call Names%Add('paramnames/derived_LSS.paramnames')
    if (CosmoSettings%compute_tensors) call Names%Add('paramnames/derived_tensors.paramnames')
    !Add output ranges to match priors
    call Names%AddDerivedRange('zrei', mn=this%use_min_zre)
    call Names%AddDerivedRange('H0', this%H0_min, this%H0_max)
    this%num_derived = Names%num_derived
    !set number of hard parameters, number of initial power spectrum parameters
    call this%SetTheoryParameterNumbers(16,last_power_index)

    end subroutine TP_Init

    function TP_NonBaseParameterPriors(this,CMB)
    class(ThetaParameterization) :: this
    class(TTheoryParams) :: CMB
    real(mcp):: TP_NonBaseParameterPriors

    select type (CMB)
    class is (CMBParams)
        TP_NonBaseParameterPriors = logZero
        if (CMB%H0 < this%H0_min .or. CMB%H0 > this%H0_max) return
        if (CMB%zre < this%Use_min_zre) return
        if (CMB%omnuh2_sterile > 0 .and. CMB%nnu > standard_neutrino_neff) then
            !Check if physical mass of thermal massive sterile too big (look like CDM, so don't need to model separately)
            if (CMB%omnuh2_sterile*neutrino_mass_fac/(CMB%nnu-standard_neutrino_neff)**0.75_mcp > this%sterile_mphys_max) return
        end if
        TP_NonBaseParameterPriors = 0
        if (this%H0_prior_mean/=0._mcp) then
            TP_NonBaseParameterPriors = ((CMB%H0 - this%H0_prior_mean)/this%H0_prior_std)**2/2
        end if
        if (this%zre_prior_mean/=0._mcp) then
            TP_NonBaseParameterPriors = TP_NonBaseParameterPriors + ((CMB%zre - this%zre_prior_mean)/this%zre_prior_std)**2/2
        end if
    end select
    end function TP_NonBaseParameterPriors

    subroutine TP_ParamArrayToTheoryParams(this, Params, CMB)
    class(ThetaParameterization) :: this
    class(TCalculationAtParamPoint) :: Params
    integer, parameter :: ncache =2
    Class(TTheoryParams), target :: CMB
    Type(CMBParams), save :: LastCMB(ncache)
    real(mcp) DA
    real(mcp)  D_b,D_t,D_try,try_b,try_t, lasttry
    integer, save :: cache=1
    integer i
    Type(CMBParams), pointer :: CP2
    integer error

    select type(CosmoCalc=>this%Config%Calculator)
    class is (TCosmologyCalculator)
        select type (CMB)
        class is (CMBParams)
            do i=1, ncache
                !want to save two slow positions for some fast-slow methods
                if (all(Params%P(1:num_hard) == LastCMB(i)%BaseParams(1:num_hard))) then
                    CP2 => CMB !needed to make next line work for some odd reason CMB=LastCMB(i) does not work
                    CP2 = LastCMB(i)
                    call this%TCosmologyParameterization%ParamArrayToTheoryParams(Params, CMB)
                    call SetFast(Params%P,CMB)
                    return
                end if
            end do
            call this%TCosmologyParameterization%ParamArrayToTheoryParams(Params, CMB)

            error = 0   !JD to prevent stops when using bbn_consistency or m_sterile
            DA = Params%P(3)/100
            try_b = this%H0_min
            call SetForH(Params%P,CMB,try_b, .true.,error)  !JD for bbn related errors
            if(error/=0)then
                cmb%H0=0
                return
            end if
            D_b = CosmoCalc%CMBToTheta(CMB)
            try_t = this%H0_max
            call SetForH(Params%P,CMB,try_t, .false.)
            D_t = CosmoCalc%CMBToTheta(CMB)
            if (DA < D_b .or. DA > D_t) then
                if (Feedback>1) write(*,*) instance, 'Out of range finding H0: ', real(Params%P(3))
                cmb%H0=0 !Reject it
            else
                lasttry = -1
                do
                    call SetForH(Params%P,CMB,(try_b+try_t)/2, .false.)
                    D_try = CosmoCalc%CMBToTheta(CMB)
                    if (D_try < DA) then
                        try_b = (try_b+try_t)/2
                    else
                        try_t = (try_b+try_t)/2
                    end if
                    if (abs(D_try - lasttry)< 1e-7) exit
                    lasttry = D_try
                end do

                if (CMB%tau==0._mcp) then
                    CMB%zre=0
                else
                    CMB%zre = CosmoCalc%GetZreFromTau(CMB, CMB%tau)
                end if

                LastCMB(cache) = CMB
                cache = mod(cache,ncache)+1
            end if
        end select
    class default
        call MpiStop('CosmologyParameterizations: Calculator is not TCosmologyCalculator')
    end select

    end subroutine TP_ParamArrayToTheoryParams

    subroutine TP_CalcDerivedParams(this, Params, Theory, derived)
    class(ThetaParameterization) :: this
    real(mcp), allocatable :: derived(:)
    class(TTheoryPredictions), allocatable :: Theory
    class(TCalculationAtParamPoint) :: Params
    Type(CMBParams) CMB
    real(mcp) :: lograt
    integer ix,i
    real(mcp) z
    integer, parameter :: derivedCL(5) = [40, 220, 810, 1420, 2000]

    if (.not. allocated(Theory)) call MpiStop('Not allocated theory!!!')
    select type (Theory)
    class is (TCosmoTheoryPredictions)
        allocate(Derived(this%num_derived), source=0._mcp)

        call this%ParamArrayToTheoryParams(Params,CMB)

        derived(1) = CMB%H0
        derived(2) = CMB%omv
        derived(3) = CMB%omdm+CMB%omb
        derived(4) = CMB%omdmh2 + CMB%ombh2
        derived(5) = CMB%omnuh2
        derived(6) = (CMB%omdmh2 + CMB%ombh2)*CMB%h

        derived(7) = Theory%Sigma_8
        derived(8) = Theory%Sigma_8*((CMB%omdm+CMB%omb)/0.3)**0.5_mcp
        derived(9) = Theory%Sigma_8*((CMB%omdm+CMB%omb))**0.5_mcp
        derived(10)= Theory%Sigma_8*((CMB%omdm+CMB%omb))**0.25_mcp
        derived(11)= Theory%Sigma_8/CMB%h**0.5_mcp
        derived(12) = Theory%derived_parameters( derived_rdrag )*CMB%H0/100
        derived(13) = Theory%Lensing_rms_deflect
        derived(14) = CMB%zre
        ix=15
        derived(ix) = cl_norm*CMB%InitPower(As_index)*1e9
        derived(ix+1) = derived(ix)*exp(-2*CMB%tau)  !A e^{-2 tau}
        ix = ix+2

        if(CosmoSettings%use_CMB .and. allocated(Theory%Cls(1,1)%CL)) then
            !L(L+1)C_L/2pi at various places
            derived(ix:ix+size(DerivedCL)-1) = Theory%Cls(1,1)%CL(derivedCL)
        end if
        ix = ix+size(derivedCL)

        lograt = log(0.002_mcp/CosmoSettings%pivot_k)   !get ns at k=0.002
        derived(ix) = CMB%InitPower(ns_index) +CMB%InitPower(nrun_index)*lograt +&
            CMB%InitPower(nrunrun_index)*lograt**2/2
        ix=ix+1

        derived(ix)= CMB%Yhe !value actually used, may be set from bbn consistency
        derived(ix+1)= GetYpBBN(CMB%Yhe) !same, as nucleon ratio definition
        ix = ix+2

        if (CosmoSettings%bbn_consistency) then
            derived(ix) = 1d5*BBN_DH%Value(CMB%ombh2,CMB%nnu - standard_neutrino_neff)
            ix =ix + 1
        end if

        derived(ix:ix + Theory%numderived-1) = Theory%derived_parameters(1: Theory%numderived)
        ix = ix + Theory%numderived

        if (CosmoSettings%Use_LSS) then
            ! f sigma_8 at specified redshift
            do i=1,size(CosmoSettings%z_outputs)
                z =  CosmoSettings%z_outputs(i)
                derived(ix) = Theory%growth_z%Value(z)
                derived(ix+1) = Theory%sigma8_z%Value(z)
                ix = ix + 2
            end do
        end if

        if (CosmoSettings%Compute_tensors) then
            derived(ix:ix+5) = [Theory%tensor_ratio_02, Theory%tensor_ratio_BB, log(max(1e-15_mcp,Theory%tensor_AT)*1e10_mcp), &
                Theory%tensor_ratio_C10, Theory%tensor_AT*1e9, Theory%tensor_AT*1e9*exp(-2*CMB%tau) ]
            ix=ix+6
        end if

        if (ix - 1 /= this%num_derived) then
            write(*,*) 'num_derived =', this%num_derived, '; ix, Theory%numderived = ', ix, Theory%numderived
            call MpiStop('TP_CalcDerivedParams error in derived parameter numbers')
        end if
    end select

    end subroutine TP_CalcDerivedParams

    subroutine SetFast(Params,CMB)
    real(mcp) Params(num_Params)
    Type(CMBParams) CMB

    CMB%InitPower(1:num_initpower) = Params(index_initpower:index_initpower+num_initpower-1)
    CMB%InitPower(As_index) = exp(CMB%InitPower(As_index))

    end subroutine SetFast

    subroutine SetForH(Params,CMB,H0, firsttime,error)
    use bbn
    use settings
    real(mcp) Params(num_Params)
    logical, intent(in) :: firsttime
    Type(CMBParams) CMB
    real(mcp) h2,H0
    integer, optional :: error

    CMB%H0=H0
    if (firsttime) then
        CMB%reserved = 0
        CMB%ombh2 = Params(1)
        CMB%tau = params(4) !tau, set zre later
        CMB%Omk = Params(5)
        CMB%w = Params(8)
        CMB%wa = Params(9)
        CMB%nnu = Params(10) !3.046
        !Params(6) is now mnu, where mnu is physical standard neutrino mass and we assume standard heating
        CMB%sum_mnu_standard = Params(6)
        if (CMB%nnu > standard_neutrino_neff .or. CosmoSettings%neutrino_hierarchy /= neutrino_hierarchy_degenerate) then
            CMB%omnuh2=Params(6)/neutrino_mass_fac*(standard_neutrino_neff/3)**0.75_mcp
        else
            CMB%omnuh2=Params(6)/neutrino_mass_fac*(CMB%nnu/3)**0.75_mcp
        end if
        !Params(7) is mass_sterile*Neff_sterile
        CMB%omnuh2_sterile = Params(7)/neutrino_mass_fac
        !we are using interpretation where there are degeneracy_factor neutrinos, each exactly thermal
        !So internally 3.046 or 3.046/3 massive neutrnos. But mnu is the physical integer mass sum.
        if (CMB%omnuh2_sterile >0 .and. CMB%nnu < standard_neutrino_neff) then
            if(present(error))then
                error=-1
            else
                call MpiStop('sterile neutrino mass required Neff>3.046')
            end if
        end if

        CMB%omnuh2 = CMB%omnuh2 + CMB%omnuh2_sterile
        CMB%omch2 = Params(2)
        CMB%omdmh2 = CMB%omch2+ CMB%omnuh2
        CMB%nufrac=CMB%omnuh2/CMB%omdmh2

        if (CosmoSettings%bbn_consistency) then
            CMB%YHe = BBN_YHe%Value(CMB%ombh2,CMB%nnu - standard_neutrino_neff,error)
        else
            !e.g. set from free parameter..
            CMB%YHe  =Params(11)
        end if

        CMB%iso_cdm_correlated =  Params(12)
        CMB%zre_delta = Params(13)
        CMB%ALens = Params(14)
        CMB%ALensf = Params(15)
        CMB%fdm = Params(16)
        call SetFast(Params,CMB)
    end if

    CMB%h = CMB%H0/100
    h2 = CMB%h**2
    CMB%omb = CMB%ombh2/h2
    CMB%omc = CMB%omch2/h2
    CMB%omnu = CMB%omnuh2/h2
    CMB%omdm = CMB%omdmh2/h2
    CMB%omv = 1- CMB%omk - CMB%omb - CMB%omdm

    end subroutine SetForH

    !!! Simple parameterization for background data, e.g. Supernovae only (no thermal history)
    subroutine BK_Init(this, Ini, Names, Config)
    class(BackgroundParameterization) :: this
    class(TSettingIni) :: Ini
    class(TParamNames) :: Names
    class(TGeneralConfig), target :: Config

    this%late_time_only = .true.
    call this%Initialize(Ini,Names, 'paramnames/params_background.paramnames', Config)
    call this%SetTheoryParameterNumbers(Names%num_MCMC,0)

    end subroutine BK_Init

    subroutine BK_ParamArrayToTheoryParams(this, Params, CMB)
    class(BackgroundParameterization) :: this
    class(TCalculationAtParamPoint) :: Params
    class(TTheoryParams), target :: CMB
    real(mcp) omegam, h2

    select type (CMB)
    class is (CMBParams)
        omegam = Params%P(1)
        CMB%H0 = Params%P(2)
        CMB%omk = Params%P(3)
        CMB%omnuh2=Params%P(4)/neutrino_mass_fac*(standard_neutrino_neff/3)**0.75_mcp
        CMB%w =    Params%P(5)
        CMB%wa =    Params%P(6)
        CMB%nnu =    Params%P(7)

        CMB%h=CMB%H0/100
        h2 = CMB%h**2
        CMB%Yhe=0.24
        CMB%omnu = CMB%omnuh2/h2
        CMB%omb= omegam - CMB%omnu
        CMB%ombh2 = CMB%omb*h2
        CMB%omc=0
        CMB%omch2 = CMB%omc*h2
        CMB%zre=0
        CMB%tau=0
        CMB%omdmh2 = CMB%omch2+ CMB%omnuh2
        CMB%omdm = CMB%omdmh2/h2
        CMB%omv = 1- CMB%omk - CMB%omb - CMB%omdm
        CMB%nufrac=CMB%omnuh2/CMB%omdmh2
        CMB%reserved=0
        CMB%fdm=0
        CMB%iso_cdm_correlated=0
        CMB%Alens=1
    end select
    end subroutine BK_ParamArrayToTheoryParams


    subroutine BK_CalcDerivedParams(this, Params, Theory, derived)
    class(BackgroundParameterization) :: this
    real(mcp), allocatable :: derived(:)
    class(TTheoryPredictions), allocatable :: Theory
    class(TCalculationAtParamPoint) :: Params
    Type(CMBParams) CMB

    allocate(Derived(1))

    call this%ParamArrayToTheoryParams(Params,CMB)

    derived(1) = CMB%omv

    end subroutine BK_CalcDerivedParams

    !Astro parameterization using H0, omegam, omegab...
    subroutine AP_Init(this, Ini, Names, Config)
    class(AstroParameterization) :: this
    class(TSettingIni) :: Ini
    class(TParamNames) :: Names
    class(TGeneralConfig), target :: Config
    character(LEN=:), pointer :: prior

    prior => Ini%Read_String('prior[omegabh2]',NotFoundFail=.false.)
    if (prior/='') then
        read(prior,*) this%ombh2_prior_mean, this%ombh2_prior_std
    end if

    call this%Initialize(Ini,Names, 'paramnames/params_astro.paramnames', Config)
    call this%SetTheoryParameterNumbers(9,last_power_index)

    end subroutine AP_Init

    function AP_NonBaseParameterPriors(this,CMB)
    class(AstroParameterization) :: this
    class(TTheoryParams) :: CMB
    real(mcp):: AP_NonBaseParameterPriors

    select type (CMB)
    class is (CMBParams)
        AP_NonBaseParameterPriors = 0
        if (this%ombh2_prior_mean/=0._mcp) then
            AP_NonBaseParameterPriors = ((CMB%ombh2 - this%ombh2_prior_mean)/this%ombh2_prior_std)**2/2
        end if
    end select
    end function AP_NonBaseParameterPriors

    subroutine AP_ParamArrayToTheoryParams(this, Params, CMB)
    class(AstroParameterization) :: this
    class(TCalculationAtParamPoint) :: Params
    class(TTheoryParams), target :: CMB
    real(mcp) omegam, h2
    integer error

    select type (CMB)
    class is (CMBParams)
        omegam = Params%P(1)
        CMB%omb= Params%P(2)
        CMB%H0 = Params%P(3)
        CMB%omk = Params%P(4)
        CMB%sum_mnu_standard = Params%P(5)
        CMB%omnuh2=Params%P(5)/neutrino_mass_fac*(standard_neutrino_neff/3)**0.75_mcp

        CMB%h=CMB%H0/100
        h2 = CMB%h**2

        CMB%omnu = CMB%omnuh2/h2
        CMB%ombh2 = CMB%omb*h2
        CMB%omc= omegam - CMB%omb - CMB%omnu
        CMB%omch2 = CMB%omc*h2

        CMB%w =    Params%P(6)
        CMB%wa =   Params%P(7)
        CMB%nnu =  Params%P(8)
        if (CosmoSettings%bbn_consistency) then
            CMB%YHe = BBN_YHe%Value(CMB%ombh2,CMB%nnu - standard_neutrino_neff,error)
        else
            CMB%YHe = Params%P(9)
        end if

        CMB%InitPower(1:num_initpower) = Params%P(index_initpower:index_initpower+num_initpower-1)
        !CMB%InitPower(As_index) = exp(CMB%InitPower(As_index))
        CMB%InitPower(As_index) = CMB%InitPower(As_index) *10 !input is 10^9 As, cl_norm = 1e-10

        CMB%zre=0
        CMB%zre_delta = 1.5
        CMB%tau=0
        CMB%omdmh2 = CMB%omch2+ CMB%omnuh2
        CMB%omdm = CMB%omdmh2/h2
        CMB%omv = 1- CMB%omk - CMB%omb - CMB%omdm
        CMB%nufrac=CMB%omnuh2/CMB%omdmh2
        CMB%reserved=0
        CMB%fdm=0
        CMB%ALensf = 1
        CMB%iso_cdm_correlated=0
        CMB%Alens=1
        CMB%omnuh2_sterile = 0

    end select
    end subroutine AP_ParamArrayToTheoryParams


    subroutine AP_CalcDerivedParams(this, Params, Theory, derived)
    class(AstroParameterization) :: this
    real(mcp), allocatable :: derived(:)
    class(TTheoryPredictions), allocatable :: Theory
    class(TCalculationAtParamPoint) :: Params
    Type(CMBParams) CMB

    allocate(Derived(9))

    call this%ParamArrayToTheoryParams(Params,CMB)

    if (.not. allocated(Theory)) call MpiStop('Not allocated theory!!!')
    select type (Theory)
    class is (TCosmoTheoryPredictions)
        derived(1) = CMB%ombh2
        derived(2) = CMB%omch2
        derived(3) = CMB%omv
        derived(4) = CMB%omnuh2
        derived(5) = log(CMB%InitPower(As_index))
        derived(6) = Theory%Sigma_8
        derived(7) = Theory%Sigma_8*((CMB%omdm+CMB%omb)/0.3)**0.5_mcp
        derived(8) = Theory%Sigma_8*((CMB%omdm+CMB%omb))**0.5_mcp
        derived(9) = Theory%Sigma_8*((CMB%omdm+CMB%omb))**0.25_mcp
    end select

    end subroutine AP_CalcDerivedParams


    end module CosmologyParameterizations
