module smoothness_prior
use MGCAMB
use CosmologyTypes
use CosmoTheory
use Likelihood_Cosmology
implicit none
private

  type, extends(TCosmoCalcLikelihood) :: SMPriorLikelihood

    contains
    procedure :: LogLikeTheory => smoothness_prior_LnLike
  end type SMPriorLikelihood

 !logical :: use_standard_prior
 character*256 :: prior_filename 

 public SMPriorLikelihood, SMPriorLikelihood_Add, prior_filename
 contains


    subroutine SMPriorLikelihood_Add(LikeList, Ini)
    class(TLikelihoodList) :: LikeList
    Type(TSettingIni) :: ini
    Type(SMPriorLikelihood), pointer :: this


	if (Ini%Read_Logical('use_SMPrior',.false.)) then
        allocate(this)
        !use_standard_prior=Ini%Read_Logical('use_standard_prior',.false.)
		this%LikelihoodType = 'SMPrior'
        this%name='SMPrior'
        this%needs_background_functions = .true.
        call LikeList%Add(this)
    end if

    end subroutine SMPriorLikelihood_Add

! =============MGXrecon=============
 real(mcp) function smoothness_prior_LnLike(this, CMB)
  implicit none

  Class(SMPriorLikelihood) :: this
  Class(CMBParams) CMB  
  integer  i, j
  real(dl) chi2
  real(dl) ::  invcov((nnode+1)*3,(nnode+1)*3), vec((nnode+1)*3), diff((nnode+1)*3)
  real(dl) ::  tmpvec(nnode+1)
  real(dl) ::  muraw(nnode+1),musm(nnode+1)
  real(dl) ::  sigmaraw(nnode+1),sigmasm(nnode+1)
  real(dl) ::  xraw(nnode+1),xsm(nnode+1) 

  invcov=0

      open(unit=50, file='data/'//trim(adjustl(prior_filename)))

       do i=1, (nnode+1)*3
         read(50,*) invcov(i,:)
       end do
       
      close(50)
       	  
	 muraw(1:nnode+1)             = CMB%mu_arr(1:nnode+1) 
	 sigmaraw(1:nnode+1)          = CMB%sigma_arr(1:nnode+1) 
	 xraw(1:nnode+1)              = CMB%X_arr(1:nnode+1) 
	 
	 call running_averg(muraw,    musm, nnode+1)
	 call running_averg(sigmaraw, sigmasm, nnode+1)
	 call running_averg(xraw,     xsm, nnode+1)
	 
	 diff(1:nnode+1)              = sigmaraw(1:nnode+1)-sigmasm(1:nnode+1)
	 diff(nnode+2:2*(nnode+1))    = muraw(1:nnode+1)-musm(1:nnode+1)
	 diff(2*nnode+3:3*(nnode+1))  = xraw(1:nnode+1)-xsm(1:nnode+1)
	 
    chi2=0
 
      do i=1, (nnode+1)*3
      do j=1, (nnode+1)*3
!LP Manually rescaled by 0.01
!       chi2=chi2+0.01*diff(i)*invcov(i,j)*diff(j)
      chi2=chi2+diff(i)*invcov(i,j)*diff(j)
      end do
      end do
 
    smoothness_prior_LnLike =  chi2/2.0
    
    write(*,*) 'Smoothness_Prior_LnLike=',smoothness_prior_LnLike
    
    
  end function smoothness_prior_LnLike

! =============MGXrecon=============  
  
  subroutine running_averg(infunc, outfunc, n)
  implicit none
  integer i,n
  real(mcp) :: infunc(n), outfunc(n)
   
  outfunc(1)   = sum(infunc(1:3))/3.d0 
  outfunc(n)   = sum(infunc(n-2:n))/3.d0 

  outfunc(2)   = sum(infunc(1:3))/3.d0 
  outfunc(n-1)   = sum(infunc(n-2:n))/3.d0 

  
  do i=3, n-2
   outfunc(i) = sum(infunc(i-2:i+2))/5.d0  
  end do
   
  end subroutine running_averg


  subroutine reorder(invec, outvec, n)
  implicit none
  integer i,n
  real(mcp) :: invec(n), outvec(n)
      
    
  do i=1, n
   outvec(i) = invec(n-i+1)
  end do
 
  end subroutine reorder
 
end module smoothness_prior

