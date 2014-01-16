! DART software - Copyright 2004 - 2013 UCAR. This open source software is
! provided by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!
! $Id$

! BEGIN DART PREPROCESS KIND LIST
! VORTEX_LAT, KIND_VORTEX_LAT
! VORTEX_LON, KIND_VORTEX_LON
! VORTEX_PMIN, KIND_VORTEX_PMIN
! VORTEX_WMAX, KIND_VORTEX_WMAX
! END DART PREPROCESS KIND LIST

! BEGIN DART PREPROCESS USE OF SPECIAL OBS_DEF MODULE
!   use obs_def_vortex_mod, only : get_expected_vortex_info_distrib
! END DART PREPROCESS USE OF SPECIAL OBS_DEF MODULE

! BEGIN DART PREPROCESS GET_EXPECTED_OBS_FROM_DEF
!         case(VORTEX_LAT)
!            call get_expected_vortex_info_distrib(state_ens_handle, win, location, expected_obs, 'lat',istatus)
!         case(VORTEX_LON)
!            call get_expected_vortex_info_distrib(state_ens_handle, win, location, expected_obs, 'lon',istatus)
!         case(VORTEX_PMIN)
!            call get_expected_vortex_info_distrib(state_ens_handle, win, location, expected_obs, 'pmi',istatus)
!         case(VORTEX_WMAX)
!            call get_expected_vortex_info_distrib(state_ens_handle, win, location, expected_obs, 'wma',istatus)
! END DART PREPROCESS GET_EXPECTED_OBS_FROM_DEF

! BEGIN DART PREPROCESS READ_OBS_DEF
!      case(VORTEX_LAT)
!         continue
!      case(VORTEX_LON)
!         continue
!      case(VORTEX_PMIN)
!         continue
!      case(VORTEX_WMAX)
!         continue
! END DART PREPROCESS READ_OBS_DEF

! BEGIN DART PREPROCESS WRITE_OBS_DEF
!      case(VORTEX_LAT)
!         continue
!      case(VORTEX_LON)
!         continue
!      case(VORTEX_PMIN)
!         continue
!      case(VORTEX_WMAX)
!         continue
! END DART PREPROCESS WRITE_OBS_DEF

! BEGIN DART PREPROCESS INTERACTIVE_OBS_DEF
!      case(VORTEX_LAT)
!         continue
!      case(VORTEX_LON)
!         continue
!      case(VORTEX_PMIN)
!         continue
!      case(VORTEX_WMAX)
!         continue
! END DART PREPROCESS INTERACTIVE_OBS_DEF

! BEGIN DART PREPROCESS MODULE CODE
module obs_def_vortex_mod

use        types_mod, only : r8, missing_r8, ps0, PI, gravity
use    utilities_mod, only : register_module, error_handler, E_ERR
use     location_mod, only : location_type, write_location, read_location
use  assim_model_mod, only : interpolate_distrib
use     obs_kind_mod, only : KIND_U_WIND_COMPONENT, KIND_V_WIND_COMPONENT, &
                             KIND_TEMPERATURE, KIND_VERTICAL_VELOCITY, &
                             KIND_RAINWATER_MIXING_RATIO, KIND_DENSITY, &
                             KIND_VORTEX_LAT, KIND_VORTEX_LON, KIND_VORTEX_PMIN, &
                             KIND_VORTEX_WMAX

use data_structure_mod, only : ensemble_type

implicit none
private

public :: get_expected_vortex_info_distrib

! version controlled file description for error handling, do not edit
character(len=256), parameter :: source   = &
   "$URL$"
character(len=32 ), parameter :: revision = "$Revision$"
character(len=128), parameter :: revdate  = "$Date$"

logical, save :: module_initialized = .false.

! Storage for the special information required for observations of this type
integer, parameter  :: max_vortex_obs = 3000

contains

!----------------------------------------------------------------------

subroutine initialize_module

call register_module(source, revision, revdate)
module_initialized = .true.

end subroutine initialize_module

!----------------------------------------------------------------------

subroutine get_expected_vortex_info_distrib(state_ens_handle, win, location, vinfo, whichinfo, istatus)

!
! Return vortex info according to whichinfo
! whichinfo='lat', vinfo = center lat
! whichinfo='lon', vinfo = center lon
! whichinfo='pmi', vinfo =  minimum sea level pressure
!

type(ensemble_type), intent(in)     :: state_ens_handle
integer,             intent(in)     :: win !> window for one sided communication
type(location_type), intent(inout)  :: location
character(len=3),    intent(in)     :: whichinfo
real(r8),            intent(out)    :: vinfo(:)
integer,             intent(out)    :: istatus(:)

integer :: e, ens_size

if ( .not. module_initialized ) call initialize_module

if (whichinfo == 'lat') then
   call interpolate_distrib(location, KIND_VORTEX_LAT, istatus, vinfo, state_ens_handle, win)
else if (whichinfo == 'lon') then
   call interpolate_distrib(location, KIND_VORTEX_LON, istatus, vinfo, state_ens_handle, win)
else if (whichinfo == 'pmi') then
   call interpolate_distrib(location, KIND_VORTEX_PMIN, istatus, vinfo, state_ens_handle, win)
else if (whichinfo == 'wma') then
   call interpolate_distrib(location, KIND_VORTEX_WMAX, istatus, vinfo, state_ens_handle, win)
else
endif

do e = 1, ens_size
   if (istatus(e) /= 0) then
      vinfo(e) = missing_r8
   endif
enddo

end subroutine get_expected_vortex_info_distrib

end module obs_def_vortex_mod
! END DART PREPROCESS MODULE CODE

! <next few lines under version control, do not edit>
! $URL$
! $Id$
! $Revision$
! $Date$
