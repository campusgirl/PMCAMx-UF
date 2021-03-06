
c     **************************************************
c     *  CAMx2so4cond                                  *
c     **************************************************

c     WRITTEN BY JaeGun Jung, Feb 2008
c                                                                   
c     This subroutine is a linker between PMCAMx aqueous 
c     chemistry and aqueous oxidation in DMAN converting following variables.
c  
c     +-+-------------------------+-----------+----------------+
c     | | name                    | input     | output         |
c     +-+-------------------------+-----------+----------------+
c     |1| pressure                | pressure  | pres           |
c     |2| relative humdity        | rh        | relh           |
c     |3| H2SO4 conc.             | q(+ih2so4)| h2so4          | 
c     |4| NH3 conc.               | q(+inh3)  | nh3ppt         |
c     |5| number conc.            | q(+knum)  | Nk(ibins)      |
c     |6| mass conc.              | q(+k...)  | Mk(ibins,icomp)| 
c     +-+-------------------------+-----------+----------------+
c     

      subroutine CAMx2so4cond(q,t0,t1,tempK,pressure,moxid0
     &                    ,ich,jch,kch)
c
c-----Include files
c
      include 'dynamic.inc'
      include 'aerpar.inc'
      include 'camx_aero.inc'
      include 'droppar.inc'
      include 'dropcom.inc'
cdbg      include 'aervaria.inc'

      integer ibins, icomp
      integer naqbin
      parameter (ibins=41, icomp=4)
      parameter (naqbin=2)
c
c-----Argument declarations
c
      real*8 q(ntotal) !particles mass [=] ugr/m3, number [=]#/cm3, gas [=]ppm
      real*8 t0, t1
      real tempK      ! temperature [=] K
      real pressure   ! atm
cdbg      real dsulfdt    !sulfuric acid production rate
      real*4 moxid0(ibins+naqbin,naers)
                       !Inert species from the aqueous chemistry routine
		       !(BNM)
                      !sulfate produced by aqueous chemistry [=]ug/m3
      integer ich, jch, kch ! coordiate, x, y, z
c
c-----Variable declarations
c
      integer srtso4, srtorg, srtnh3, srth2o !species indicators
      parameter (srtso4=1, srtorg=2, srtnh3=3, srth2o=4)

      integer i, j ! counter variables
      integer ii, jj ! counter variables
      integer iflag ! a flag for checking a negative mass
      integer ifind ! a finder for iactiv
      integer iact  ! a starting activation diameter
c
      double precision Nk(ibins)       ! Number concentrations
      double precision Mk(ibins,icomp) ! Mass concentrations
      double precision xk(ibins+1)     ! bins' boundary mass [=] kg
      double precision Neps, Meps
      double precision totmass, newmass! For updating Nk when Mk is less
                                       ! than zero.
      double precision eps
      double precision Nkout(ibins)       ! Number concentrations output
      double precision Mkout(ibins,icomp) ! Mass concentrations output
cnogas      double precision Gc(icomp-1), Gcout(icomp-1) !Gas species
c
cnogas      real h2so4      ! sulfuric acid gas [=] ppt
cnogas      real nh3ppt     ! ammonia gas [=] ppt
      real relh       ! relative humidity
      real tstart     ! starting time and ending time of simulation
      real tend       ! starting time and ending time of simulation
      real boxvol     ! A volume of arbitrary box
      real pres       ! Pa 

      real rt_pom(ibins), rt_ec(ibins), rt_crst(ibins), rt_cl(ibins),
     &    rt_na(ibins)
     & , rt_no3(ibins) ! Ratios of each inert component                 ! cf

      real add_rt_pom(ibins), add_rt_ec(ibins), add_rt_crst(ibins),
     &    add_rt_cl(ibins), add_rt_na(ibins), add_rt_soa1(ibins),
     &    add_rt_soa2(ibins), add_rt_soa3(ibins), add_rt_soa4(ibins)
     &    ,add_rt_no3(ibins) ! Ratios of each inert component added    ! cf
      real tot_inert(ibins) ! total inert mass
      real tot_inert2(ibins) ! total inert mass after calling dman
cdbg      real eps
      real cvt, cvt2
      real*4 moxid(ibins,icomp-1)
cnogas      real R ! gas constant
cnogas      real boxmass ! mass of grid cell (kg)
cnogas      real gmw(icomp) !gas molecular weight
cnogas      data gmw/98.,50.,17.,18./
      real deltat
      real dt ! [=] sec
      real add_tot_inert(ibins) ! added tot_inert by an aqueous chemistry
      real dtot_inert(ibins)    ! tot_inert changed after the process
c
c-----Adjustable parameters
c
      parameter (Neps=1.0d-10, Meps=1.0d-20)
      parameter (eps = 1.0d-20)
      parameter (boxvol = 3.0d20) ! cm3, arbitrary value
      parameter (cvt = 1.0d-15)   ! a convert factor from ug/m3 to kg/cm3
      parameter (cvt2 = 1.0d+15)  ! a covert factor from kg/cm3 to ug/m3
cnogas      parameter (R = 8.314) ! gas constant, J/mol-K
c
c-----Code--------------------------------------------------------------
c
      ! Set variables
      iflag = 0 
      ! Set xk's
      xk(1) = 3.75315d-25 ! kg
      do i = 1, ibins
         xk(i+1) = 2.0 * xk(i)
      enddo

      ! Adjust unit of timestep 
      tstart = t0/3600. ![=]hr
      tend = t1/3600.   ![=]hr

      ! Converting PMCAMx variables to DMAN variables
      pres = pressure * 1.01325d5 ! Pa
      relh = rh ! Change a relative humidity variable for DMAN
c
      moxid=0.0
      Mk=0.d0
c
      do i=1, ibins !Transfer moxid0
      ! Check negative moxid0
      if (moxid0(i,naa).lt.0.0) moxid0(i,naa)=0.0            
      if (moxid0(i,na4).lt.0.0) moxid0(i,na4)=0.0
      if (moxid0(i,nan).lt.0.0) moxid0(i,nan)=0.0
      if (moxid0(i,nas).lt.0.0) moxid0(i,nas)=0.0
      if (moxid0(i,nao).lt.0.0) moxid0(i,nao)=0.0
      if (moxid0(i,nae).lt.0.0) moxid0(i,nae)=0.0
      if (moxid0(i,nar).lt.0.0) moxid0(i,nar)=0.0
      if (moxid0(i,nac).lt.0.0) moxid0(i,nac)=0.0
c
         moxid(i,srtnh3)=moxid0(i,naa)*cvt*boxvol
         moxid(i,srtso4)=moxid0(i,na4)*cvt*boxvol
         add_tot_inert(i) = moxid0(i,nan)+moxid0(i,nas)+         ! cf
c                            ! Nitrate                 Na              !
c         add_tot_inert(i) = moxid0(i,kna_c)+                          ! cf
                     !        Na
     &                moxid0(i,nac)+moxid0(i,nao)+
                     ! Cl                OC
     &                moxid0(i,nae)+moxid0(i,nar)+
                     ! EC                Crust
     &                eps
                     ! for safety
         ! Capture ratios added before calling dman 
         add_rt_no3(i)   = moxid0(i,nan) * (1.0/add_tot_inert(i))   ! cf
         add_rt_na(i)    = moxid0(i,nas) * (1.0/add_tot_inert(i))
         add_rt_cl(i)    = moxid0(i,nac) * (1.0/add_tot_inert(i))
         add_rt_pom(i)   = moxid0(i,nao) * (1.0/add_tot_inert(i))
         add_rt_ec(i)    = moxid0(i,nae) * (1.0/add_tot_inert(i))
         add_rt_crst(i)  = moxid0(i,nar) * (1.0/add_tot_inert(i))
         moxid(i,srtorg) = add_tot_inert(i)*cvt*boxvol

      enddo
     
      do i=1, ibins
         ! First check for negative tracers
         if (q((i-1)*nsp+knum).lt.0.0) then
            if (q((i-1)*nsp+knum).gt.(-Neps*(1./boxvol)))then
               q((i-1)*nsp+knum) = Neps*(1./boxvol)
               do j=2, 13 ! from KNa to KEC, all mass species wo H2O 
                  q((i-1)*nsp+j) = Neps*(1./boxvol)*1.4*xk(i)*(1./12.)
               enddo
            else
               write(*,*)'CAMx2so4cond'
               write(*,*)'Coordinate =', ich, jch, kch
               write(*,*)'Negative tracer in DMAN before dman'
               write(*,*)'sizesection=', i
               write(*,*)'q(+knum)='
               do ii=1,ibins
                  write(*,*)q((ii-1)*nsp+knum)
               enddo
               write(*,*)'q(+k...)='
               do jj=2, 13 ! from KNa to KEC, all mass species wo H2O 
                  write(*,*)'species=',jj
                  do ii=1,ibins
                     write(*,*)q((ii-1)*nsp+jj)
                  enddo
               enddo
               STOP
            endif
         endif
         totmass=0.0
         do j=2, 13 ! from KNa to KEC, all mass species wo H2O 
            totmass=totmass+q((i-1)*nsp+j)
            if (q((i-1)*nsp+j).lt.0.0) then
               if (q((i-1)*nsp+j).gt.(-Meps*(1./(cvt*boxvol)))) then
                  q((i-1)*nsp+j) = Meps*(1./(cvt*boxvol))
                  iflag=1
               else
                  write(*,*)'Coordinate =', ich, jch, kch
                  write(*,*)'Negative tracer in DMAN before dman'
                  write(*,*)'sizesection=', i
                  write(*,*)'q(+knum)='
                  do ii=1,ibins
                     write(*,*)q((ii-1)*nsp+knum)
                  enddo
                  write(*,*)'q(+k...)='
                  do jj=2, 13 ! from KNa to KEC, all mass species wo H2O 
                     write(*,*)'species=',jj
                     do ii=1,ibins
                        write(*,*)q((ii-1)*nsp+jj)
                     enddo
                  enddo
                  STOP
               endif
            endif
         enddo
         if (iflag.eq.1) then
            newmass=0.0
            do jj=2, 13 ! from KNa to KEC, all mass species wo H2O 
               newmass=newmass+q((i-1)*nsp+jj)
            enddo
            q((i-1)*nsp+knum)=q((i-1)*nsp+knum)*newmass/totmass
            iflag=0
         endif
c
         Nk(i)=q((i-1)*nsp+knum) * boxvol
              ! Nk [=] #, q [=] #/cm3, and boxvol [=] cm3
         Mk(i,srtso4)=q((i-1)*nsp+kso4) * cvt * boxvol
              ! Mk [=] kg, q [=] ug/m3
         tot_inert(i) = (q((i-1)*nsp+kpom)+q((i-1)*nsp+kec)+
                     ! POA                 EC
     &                q((i-1)*nsp+kcrus)+q((i-1)*nsp+kcl)+
                     ! CRST                Cl
     &                q((i-1)*nsp+kna)!)
                     ! Na                  
                     ! No SOA
     &                +q((i-1)*nsp+kno3))                          !  cf
                     ! Nitrate
         ! Capture ratios before calling dman 
         rt_pom(i) = q((i-1)*nsp+kpom) * (1.0/tot_inert(i))
         rt_ec(i) = q((i-1)*nsp+kec) * (1.0/tot_inert(i))
         rt_crst(i) = q((i-1)*nsp+kcrus) * (1.0/tot_inert(i))
         rt_cl(i) = q((i-1)*nsp+kcl) * (1.0/tot_inert(i))
         rt_na(i) = q((i-1)*nsp+kna) * (1.0/tot_inert(i))
         ! No SOA
         rt_no3(i) = q((i-1)*nsp+kno3) * (1.0/tot_inert(i))          !  cf
c
         Mk(i,srtorg) = tot_inert(i) * cvt * boxvol
         Mk(i,srtnh3)=q((i-1)*nsp+knh4) * cvt * boxvol
         Mk(i,srth2o)=q((i-1)*nsp+kh2o) * cvt * boxvol
      enddo      
c
c     Find a starting activation bin
c
      i = 1
      ifind = 0
c      do while (ifind.eq.1)
      do while (ifind.eq.0) ! changed by LA
        if (daer(i).gt.dactiv) then
          iact = i
          ifind = 1
c          ifind = 0  ! changed by LA
        else
          i=i+1
        endif
      enddo 

c------No gas change. It is addition  by aqueous oxidation chemistry
c

      deltat=tend-tstart
      dt=deltat*3600.

      call so4cond_oxd(Nk,Mk,Nkout,Mkout,dt,moxid,iact,ich,jch,kch,xk)  ! cf

      do i=1,ibins
        do j=1, icomp
          Mk(i,j)=Mkout(i,j)
        enddo
        Nk(i)=Nkout(i)
      enddo
c
c-----Return DMAN values to the PMCAMx variable, check I can call initbounds
c
      do i=1, ibins
         ! First check for negative tracers
         if (Nk(i).lt.0.0) then
            if (Nk(i).gt.-Neps)then
               Nk(i) = 0.0
               do j=1, icomp-1
                  Mk(i,j)=Neps*1.4*xk(i)*(1./(icomp-1))
               enddo
            else
               write(*,*)'Coordinate =', ich, jch, kch
               write(*,*)'Negative tracer in DMAN after dman'
               write(*,*)'sizesection=', i
               write(*,*)'Nk='
               do ii=1,ibins
                 write(*,*)Nk(ii)
               enddo
               write(*,*)'Mk='
               do jj=1,icomp
                  write(*,*)'species=',jj
                  do ii=1,ibins
                     write(*,*)Mk(ii,jj)
                  enddo
               enddo
               STOP
            endif
         endif
         totmass=0.0
         do j=1, icomp-1
            totmass=totmass+Mk(i,j)
            if (Mk(i,j).lt.0.0) then
               if (Mk(i,j).gt.-Meps) then
                  Mk(i,j)=0.0
                  iflag=1
               else
                  write(*,*)'Coordinate =', ich, jch, kch
                  write(*,*)'Negative tracer in DMAN after dman'
                  write(*,*)'sizesection=', i
                  write(*,*)'Nk='
                  do ii=1,ibins
                    write(*,*)Nk(ii)
                  enddo
                  write(*,*)'Mk='
                  do jj=1,icomp
                     write(*,*)'species=',jj
                     do ii=1,ibins
                        write(*,*)Mk(ii,jj)
                     enddo
                  enddo
                  STOP
               endif
            endif
         enddo
         if (iflag.eq.1) then
            newmass=0.0
            do jj=1, icomp-1
               newmass=newmass+Mk(i,jj)
            enddo
            Nk(i)=Nk(i)*newmass/totmass
            iflag=0
         endif

        ! Return the values
        q((i-1)*nsp+knum) = Nk(i) * (1.0/boxvol)
        ! Nk [=] #, q [=] #/cm3, and boxvol [=] cm3
        q((i-1)*nsp+kso4) = Mk(i,srtso4) * cvt2 * (1.0/boxvol)
        ! Mk [=] kg, q [=] ug/m3
c
c     Only POA has the sum of POA, EC, CRST, Cl, and Na. The rest of
c     species are set to zero.
c
        tot_inert2(i) = Mk(i,srtorg) * cvt2 * (1.0/boxvol)
        if (tot_inert(i).le.tot_inert2(i)) then  !Increased mass
           !Add mass in proportion to the composition of species
	   !added by the aqueous phase chemistry module
           dtot_inert(i)=tot_inert2(i)-tot_inert(i)
           q((i-1)*nsp+kpom) = q((i-1)*nsp+kpom) 
     &                        + dtot_inert(i)* add_rt_pom(i)
           q((i-1)*nsp+kec) = q((i-1)*nsp+kec)
     &                        + dtot_inert(i) * add_rt_ec(i)
           q((i-1)*nsp+kcrus) = q((i-1)*nsp+kcrus)
     &                        + dtot_inert(i) * add_rt_crst(i)
           q((i-1)*nsp+kcl) = q((i-1)*nsp+kcl)
     &                        + dtot_inert(i) * add_rt_cl(i)
           q((i-1)*nsp+kna) = q((i-1)*nsp+kna)
     &                        + dtot_inert(i) * add_rt_na(i)
           ! SOA is not added by aqueous chemistry
           q((i-1)*nsp+kno3) = q((i-1)*nsp+kno3)                      ! cf
     &                        + dtot_inert(i) * add_rt_no3(i)         ! cf
        else !Decreased Mass
           !redistribute as the portion of before aqueous chemistry
           q((i-1)*nsp+kpom) = tot_inert2(i) * rt_pom(i)
           q((i-1)*nsp+kec) = tot_inert2(i) * rt_ec(i)
           q((i-1)*nsp+kcrus) = tot_inert2(i) * rt_crst(i)
           q((i-1)*nsp+kcl) = tot_inert2(i) * rt_cl(i)
           q((i-1)*nsp+kna) = tot_inert2(i) * rt_na(i)
           ! SOA is not added by aqueous chemistry
           q((i-1)*nsp+kno3) = tot_inert2(i) * rt_no3(i)               ! cf
cdbg           write(*,*)'Inert mass by aqueous chemistry is not increased'
cdbg           write(*,*)'Inert mass before aqueous',tot_inert(i)
cdbg           write(*,*)'Inert mass after aqueous',tot_inert2(i)
cdbg           write(*,*)'Coordinate =', ich, jch, kch
cdbg           STOP
         endif   
c
         q((i-1)*nsp+knh4) = Mk(i,srtnh3) * cvt2 * (1.0/boxvol)
         ! Water is not changed by this process
      enddo      

      RETURN
      END
