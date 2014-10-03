
c
c     Omninus subroutines
c
c     1. numconv  : generates number concentrations
c     2. saveconc : save concentrations before emissions
c     3. numcheck : check number conc.s in a specific cell and write M/N
c     4. mnratios : check M/N ratios whether they are within 0.8 to 2.2
c
c
      subroutine numconv(conc,ncol,nrow,nlay,sconc,nspc,iflag)
c
c
c     NUMCONV generates number concentrations from mass concentrations.
c     During emission process, sulfate, crust, and carbonaceous particles
c     are redistributed. It is because the emission inventries are only
c     separated by fine and coarse modes. (Flat distribution within size
c     section) The redistribution follows,
c
c     Sulfate: modified AEROCOM sulfate distribution
c     Crust: Lee, Y-H's global emission from Marticorena and Bergamett (1995) 
c     Carbonaceous: Figure 3-(b) on AE39 (2005) 4155-4166
c     
c     Arguments:
c     conc ; concentrations including aerosol and gas
c     ncol ; a number of columes of whole grids
c     nrow ; a number of rows of whole grids
c     nlay ; a number of layers of whole grids
c     tmass ; total mass concentration before doing individual prcesses
c     iflag ; 0 = initial condition, implement the organinc distribution
c           ; 1 = Do not implement the initial condition
c           ; 2 = called by emistrns. Accumulate number concentration
c           ; 3 = called by emistrns if emissions are already size resolved
c
c     Called by:
c     CAMx
c     emistrns
c
c-----Variable explanation
c
      include 'camx.prm'
      include 'camx.com'
      include 'section.inc'
      include 'chmstry.com'
      include 'aerpar.inc'
      include 'diameters.inc'
c
c-----Variables
c
      integer k, j, i, ii ! counters
      integer isec, iarspc ! section #, aerosol species # 
      integer n3d, n4d ! parameters in conc matrix
      integer iflag ! different depending on calling subroutines
      integer isund
      real mass ! [=] ug/m3, total mass of each size section
      real mass2 ! [=] ug/m3, total mass for organic species
      real mass3 ! [=] ug/m3, total mass for number concentratios
      real number ! [=] #/cm3, aerosol number concentration
      real meandp3 ! [=] a cube of mean diameter of particle
c      real dist(14) !Carbonaceous redistribution
      real dist(10) !Carbonaceous redistribution
      real dist2(12), dist3(6) !Crust redistributions between 2.5 um 
      real dist4(35), dist5(6) !Sulfate redistribution between 2.5 um
      dimension conc(ncol,nrow,nlay,nspc)
      dimension sconc(ncol,nrow,nlay,nspc)
c
c-----Distribute Organic Mass based on the following paper.
c     Figure 3-(b) on AE 39 (2005) 4155-4166
c     Organic Mass includes emissions below 40 nm.
c     The species of organics correspond to the followings.
c
c     Portions of mass from 12th to 25th. The values below calculated in
c     Excel file.
c
c      data dist /5.15e-5, 1.72e-4, 4.29e-4, 9.44e-4, 1.92e-3,
c     &           3.84e-3, 1.24e-2, 4.39e-2, 9.06e-2, 1.21e-1,
c     &           1.76e-1, 1.98e-1, 1.76e-1, 1.76e-1/

c     Portions of mass from 9th to 18th. The values below calculated in
c     Excel file.

      data dist /1.70e-3, 3.32e-3, 7.70e-3, 1.73e-2, 4.29e-2,
     &           7.49e-2, 1.39e-1, 2.00e-1, 2.28e-1, 2.86e-1/
c
c-----Distribution of crust
c
c     Portions of mass from 24th to 35th. The values below calculated in
c     the excel file of "modified_crust.xls". (Less than 2.5 um)
c
      data dist2 /5.70e-7, 1.03e-5, 9.69e-5, 5.78e-4, 2.20e-3,
     &           5.96e-3, 1.33e-2, 2.77e-2, 5.93e-2, 1.29e-1,
     &           2.66e-1, 4.96e-1/
c
c     Portions of mass from 36th to 41th. The values below calculated in
c     the excel file of "modified_crust.xls". (Bigger than 2.5 um)
c
      data dist3 /1.06e-1, 1.52e-1, 1.89e-1, 2.03e-1, 1.92e-1,
     &           1.58e-1/
c
c-----Distribution of sulfate and etc
c
c     Portions of mass from 1st to 35th. The values below calculated in
c     the excel file of "modified_crust.xls". (Less than 2.5 um)
c
      data dist4 /3.98e-15, 7.69e-14, 1.27e-12, 1.81e-11, 2.20e-10,
     &           2.30e-9, 2.05e-8, 1.57e-7, 1.03e-6, 5.79e-6,
     &           2.79e-5, 1.15e-4, 4.07e-4, 1.23e-3, 3.20e-3,
     &           7.14e-3, 1.37e-2, 2.25e-2, 3.19e-2, 3.93e-2,
     &           4.24e-2, 4.08e-2, 3.59e-2, 2.96e-2, 2.32e-2,
     &           1.74e-2, 1.26e-2, 9.58e-3, 1.01e-2, 1.68e-2,
     &           3.34e-2, 6.46e-2, 1.13e-1, 1.79e-1, 2.52e-1/
c
c     Portions of mass from 36th to 41th. The values below calculated in
c     the excel file of "modified_crust.xls". (Bigger than 2.5 um)
c
      data dist5 /1.74e-1, 1.96e-1, 1.99e-1, 1.80e-1, 1.46e-1,
     &           1.06e-1/
c
      k = 1 ! Apply only surface cells
      do j = 1,nrow
         do i = 1,ncol
c
c-----Collect Organic mass in the size sections from 18 to 25,
c-----which corresponds from 40.6 nm to 258 nm.
c
cnotime            if ((time.ge.600).and.(time.lt.1800)) then !Only daytime
               do iarspc = 5, 6 !from POC to KEC (See CAMx4.chemparam.6)
                  mass2 = 0.
                  do isec = 9, 18
                     lmod = ngas + (iarspc-1)*nsec + isec
                     if ((iflag.eq.0).or.(iflag.eq.1)) then
                        mass2 = mass2 + conc(i,j,k,lmod)
                        conc(i,j,k,lmod) = 0.
                     elseif (iflag.eq.2) then !for emission
                        mass2 = mass2 + (conc(i,j,k,lmod)
     &                     - sconc(i,j,k,lmod))
                        conc(i,j,k,lmod) = sconc(i,j,k,lmod)
                     endif
                  enddo

                  !Redistribute OM to the size bins from 9th (5.08 nm) 
                  !to 18th (51.2 nm).
                  do ii = 1,10
                     isec = ii + 8
                     lmod = ngas + (iarspc-1)*nsec + isec
                     if ((iflag.eq.0).or.(iflag.eq.1)) then
                        conc(i,j,k,lmod) = mass2 * dist(ii)
                     elseif (iflag.eq.2) then !for emission
                        conc(i,j,k,lmod) = sconc(i,j,k,lmod) 
     &                    + (mass2 * dist(ii))
                     endif
                  enddo
               enddo
cnotime            endif
c
c-----Collect crustal mass in the size sections from 1 to 35,
c-----which corresponds from 0.8 nm to 2.6 um
c
            iarspc = 7 !CRST (See CAMx4.chemparam.6)
            mass2 = 0.
            do isec = 1, 35
               lmod = ngas + (iarspc-1)*nsec + isec
               if ((iflag.eq.0).or.(iflag.eq.1)) then
                  mass2 = mass2 + conc(i,j,k,lmod)
                  conc(i,j,k,lmod) = 0.
               elseif (iflag.eq.2) then !for emission
                  mass2 = mass2 + (conc(i,j,k,lmod)
     &               - sconc(i,j,k,lmod))
                  conc(i,j,k,lmod) = sconc(i,j,k,lmod)
               endif
            enddo

            !Redistribute crust to the size bins from 24th (163 nm) 
            !to 35th (2.6 nm).
            do ii = 1,12
               isec = ii + 23
               lmod = ngas + (iarspc-1)*nsec + isec
               if ((iflag.eq.0).or.(iflag.eq.1)) then
                  conc(i,j,k,lmod) = mass2 * dist2(ii)
               elseif (iflag.eq.2) then !for emission
                  conc(i,j,k,lmod) = sconc(i,j,k,lmod) 
     &              + (mass2 * dist2(ii))
               endif
            enddo
c
c     Collect crustal mass in the size sections from 36 to 41,
c     which corresponds from 2.6 um to 10.4 um
            mass2 = 0.
            do isec = 36, 41
               lmod = ngas + (iarspc-1)*nsec + isec
               if ((iflag.eq.0).or.(iflag.eq.1)) then
                  mass2 = mass2 + conc(i,j,k,lmod)
                  conc(i,j,k,lmod) = 0.
               elseif (iflag.eq.2) then !for emission
                  mass2 = mass2 + (conc(i,j,k,lmod)
     &               - sconc(i,j,k,lmod))
                  conc(i,j,k,lmod) = sconc(i,j,k,lmod)
               endif
            enddo

            !Redistribute crust to the size bins from 36th (2.6 um) 
            !to 41th (10.4 um).
            do ii = 1,6
               isec = ii + 35
               lmod = ngas + (iarspc-1)*nsec + isec
               if ((iflag.eq.0).or.(iflag.eq.1)) then
                  conc(i,j,k,lmod) = mass2 * dist3(ii)
               elseif (iflag.eq.2) then !for emission
                  conc(i,j,k,lmod) = sconc(i,j,k,lmod) 
     &              + (mass2 * dist3(ii))
               endif
            enddo
c
c-----Collect sulfate and etc in the size sections from 1 to 35,
c-----which corresponds from 0.8 nm to 2.6 um.
c
            do iarspc = 9, 13 !from PCL to PSO4 (See CAMx4.chemparam.6)
               mass2 = 0.
               do isec = 1, 35
                  lmod = ngas + (iarspc-1)*nsec + isec
                  if ((iflag.eq.0).or.(iflag.eq.1)) then
                     mass2 = mass2 + conc(i,j,k,lmod)
                     conc(i,j,k,lmod) = 0.
                  elseif (iflag.eq.2) then !for emission
                     mass2 = mass2 + (conc(i,j,k,lmod)
     &                  - sconc(i,j,k,lmod))
                     conc(i,j,k,lmod) = sconc(i,j,k,lmod)
                  endif
               enddo

               !Redistribute OM to the size bins from 1st (0.8 nm) 
               !to 35th (2.6 um).
               do ii = 1,35
                  isec = ii
                  lmod = ngas + (iarspc-1)*nsec + isec
                  if ((iflag.eq.0).or.(iflag.eq.1)) then
                     conc(i,j,k,lmod) = mass2 * dist4(ii)
                  elseif (iflag.eq.2) then !for emission
                     conc(i,j,k,lmod) = sconc(i,j,k,lmod) 
     &                 + (mass2 * dist4(ii))
                  endif
               enddo
c
c-----Collect sulfate and etc in the size sections from 36 to 41,
c-----which corresponds from 2.6 um to 10.4 um.
c
               mass2 = 0.
               do isec = 36, 41
                  lmod = ngas + (iarspc-1)*nsec + isec
                  if ((iflag.eq.0).or.(iflag.eq.1)) then
                     mass2 = mass2 + conc(i,j,k,lmod)
                     conc(i,j,k,lmod) = 0.
                  elseif (iflag.eq.2) then !for emission
                     mass2 = mass2 + (conc(i,j,k,lmod)
     &                  - sconc(i,j,k,lmod))
                     conc(i,j,k,lmod) = sconc(i,j,k,lmod)
                  endif
               enddo

              !Redistribute OM to the size bins from 36th (2.6 um) 
              !to 41th (10.4 um).
              do ii = 1,6
                 isec = ii+35
                 lmod = ngas + (iarspc-1)*nsec + isec
                 if ((iflag.eq.0).or.(iflag.eq.1)) then
                    conc(i,j,k,lmod) = mass2 * dist5(ii)
                 elseif (iflag.eq.2) then !for emission
                    conc(i,j,k,lmod) = sconc(i,j,k,lmod) 
     &                + (mass2 * dist5(ii))
                 endif
              enddo
            enddo
c
c-------------------------------------------------------------------------
c
         enddo !ncol
      enddo !nlow
c
c-----Generate number conc.
c
      do k = 1,nlay
         do j = 1,nrow
            do i = 1,ncol
               do isec = 1, nsec
                  mass = 0.
                  do iarspc = 1, naero-1
                     lmod = ngas + (iarspc-1)*nsec + isec
cdbg                     write(*,*)'spname(lmod)=',spname(lmod) !debug
                     isund=INDEX(spname(lmod),'_')
                     if (spname(lmod)(1:isund-1).ne.'PH2O') then
                        ! To avoid H2O
                        if ((iflag.eq.0).or.(iflag.eq.1)) then
                           mass = mass + conc(i,j,k,lmod) 
                        else !for emission
                           mass = mass + (conc(i,j,k,lmod)
     &                        - sconc(i,j,k,lmod))
                        endif
                     endif
                  enddo
cdbg                  pause
                  lmod = ngas + (naero-1)*nsec + isec ! number conc.
                  meandp3 = (dsec_i(isec)*dsec_i(isec+1))**(3./2.)
                  number = mass/(pi6*meandp3*rho)*1.0d12 ! # cm-3
                  if ((iflag.eq.0).or.(iflag.eq.1)) then
                     conc(i,j,k,lmod) = number
                  else !for emission
                     conc(i,j,k,lmod) = conc(i,j,k,lmod) + number
                  endif
               enddo
            enddo !ncol
         enddo !nlow
      enddo !nlay

      return
      end
c
c---------------------------------------------------------------------
c
      subroutine saveconc(conc,ncol,nrow,nlay,nspc,sconc)
c
c
c     SAVECONC generates number concentrations from mass concentrations.
c
c     Arguments:
c     conc ; concentrations including aerosol and gas
c     ncol ; a number of columes of whole grids
c     nrow ; a number of rows of whole grids
c     nlay ; a number of layers of whole grids
c     nspc ; a number of species
c     iflag ; 0 = Before emiss
c           ; 1 = After emiss
c
c     Called by:
c     CAMx
c     emistrns
c
c-----Variable explanation
c
      include 'camx.prm'
      include 'camx.com'
      include 'section.inc'
      include 'chmstry.com'
      include 'aerpar.inc'
      include 'diameters.inc'
c
c-----Variables
c
      integer k, j, i, ii, jj ! counters
      integer isec, iarspc ! section #, aerosol species # 
      integer n3d, n4d ! parameters in conc matrix
cdbg      integer iflag ! different depending on calling subroutines
      real mass ! [=] ug/m3, total mass of each size section
      real mass2 ! [=] ug/m3, total mass for organic species
      real mass3 ! [=] ug/m3, total mass for number concentratios
      real number ! [=] #/cm3, aerosol number concentration
      real meandp3 ! [=] a cube of mean diameter of particle
      real dist(14)
      dimension conc(ncol,nrow,nlay,nspc)
      dimension sconc(ncol,nrow,nlay,nspc)
c
c-----Generate number conc.
c
      do k = 1,nlay
         do j = 1,nrow
            do i = 1,ncol
               do isec = 1, nsec
                  do iarspc = 1, naero-1 
                         ! Exclude number conc.
                     lmod = ngas + (iarspc-1)*nsec + isec
                     sconc(i,j,k,lmod)=conc(i,j,k,lmod)
                  enddo
               enddo
            enddo
         enddo
       enddo
       return
       end
c
c---------------------------------------------------------------------
c
      subroutine numcheck(conc,ncol,nrow,nlay,nspc)
c
c
c     NUMCHECK checks number concentrations in a specific cell.
c
c     Arguments:
c     conc ; concentrations including aerosol and gas
c     ncol ; a number of columes of whole grids
c     nrow ; a number of rows of whole grids
c     nlay ; a number of layers of whole grids
c     tmass ; total mass concentration before doing individual prcesses
c
c     Called by:
c     CAMx
c     emstrns
c
      include 'camx.prm'
      include 'camx.com'
      include 'section.inc'
      include 'chmstry.com'
      include 'aerpar.inc'
      include 'diameters.inc'
c
c-----Variables
c
      integer k, j, i, isec, iarspc
      integer n3d, n4d
      integer isund
      real mass, number
      real meandp3
      dimension conc(ncol,nrow,nlay,nspc),
     &          xk(nsec) ! boundaries
c
c-----Generate number conc.
c
      !Pittsburgh
c      k=1
c      j=51
c      i=65

      !A problem cell
      ipcell=33
      jpcell=18
      kpcell=1
c
c Setting xk's
c
      xk(1) = 3.75315e-25 ![=]kg for rho of particles = 1.4e+12 ug/m3
      do isec = 2, nsec
         xk(isec) = xk(isec-1) * 2 
      enddo

      write(*,*)'In numcheck'

      do i=ipcell-1,ipcell+1
        do j=jpcell-1,jpcell+1
          do k=kpcell,kpcell
            do isec = 1, nsec-2 !To avoid the bins greater than 10um
              mass = 0.
              do iarspc = 1, naero-1 !To avoid number 
                 lmod = ngas + (iarspc-1)*nsec + isec
                 isund=INDEX(spname(lmod),'_')
                 if (spname(lmod)(1:isund-1).ne.'PH2O') then ! To avoid H2O
                    mass=mass+conc(i,j,k,lmod) 
                 endif
              enddo
              lmod = ngas + (naero-1)*nsec + isec
              number = conc(i,j,k,lmod)
              write(*,*)'Coordinate (i,j,k)',i,j,k
              write(*,*)'Species=',spname(lmod)
              write(*,*)'mass, number=',mass, number
              write(*,*)'M/N ratio',mass/number*1.0d-15/xk(isec)
            enddo
          enddo
        enddo
      enddo
c
cdbg      pause
c
      return
      end
c
c---------------------------------------------------------------------
      subroutine mnratios(conc,ncol,nrow,nlay,nspc,flag)
c
c     Arguments:
c     conc ; concentrations including aerosol and gas
c     ncol ; a number of columes of whole grids
c     nrow ; a number of rows of whole grids
c     nlay ; a number of layers of whole grids
c     tmass ; total mass concentration before doing individual prcesses
c
c     Called by:
c     CAMx
c     emistrns
c
c-----Variable explanation
c
      include 'camx.prm'
      include 'camx.com'
      include 'section.inc'
      include 'chmstry.com'
      include 'aerpar.inc'
      include 'diameters.inc'
c
c-----Variables
c
      integer k, j, i ! counters
      integer isec, iarspc ! section #, aerosol species # 
      integer n3d, n4d ! parameters in conc matrix
      integer iflag ! different depending on calling subroutines
      integer lmod, lmod2 ! the order of species in a given grid cell
      integer flag ! flag to know where it is called
      integer isund ! check underbar
      real mass ! [=] ug/m3, total mass of each size section
      real number ! [=] #/cm3, aerosol number concentration
      real meandp3 ! [=] a cube of mean diameter of particle
      dimension conc(ncol,nrow,nlay,nspc),
     &          rmass(ncol,nrow,nlay,nsec), 
     &          rmnratio(ncol,nrow,nlay,nsec), ! [=] kg/particle
     &          xk(nsec) ! boundaries
c
c Setting xk's
c
      xk(1) = 3.75315e-25 ![=]kg for rho of particles = 1.4e+12 ug/m3
      do isec = 2, nsec
         xk(isec) = xk(isec-1) * 2 
      enddo
c
      write(*,*)'mnratio by',flag
      do k = 1,nlay
         do j = 1, nrow
            do i = 1, ncol
               do isec = 1, nsec-2 ! neglect the size bin above 10 um
                                   ! because of lack of aerosol microphysics
                                   ! and aqueous chemistry
                  lmod2 = ngas + (naero-1)*nsec + isec
                  do iarspc = 1, naero-1 
                     ! Count mass species except number conc.
                     lmod = ngas + (iarspc-1)*nsec + isec
                     isund=INDEX(spname(lmod),'_')
                     if (spname(lmod)(1:isund-1).ne.'PH2O') then
                        ! To avoid H2O
                        rmass(i,j,k,isec) = rmass(i,j,k,isec) +  
     &                                     conc(i,j,k,lmod)
                     endif
                  enddo
                  rmnratio(i,j,k,isec) = rmass(i,j,k,isec) /
     &               conc(i,j,k,lmod2) * 1.0d-15 ! kg/particle
                  rmnratio(i,j,k,isec) = rmnratio(i,j,k,isec) /
     &               xk(isec)
                  if ((rmnratio(i,j,k,isec).lt.0.8).or.
     &              (rmnratio(i,j,k,isec).gt.2.2)) then
                    write(*,*)'Warning a size section =', isec
                    write(*,*)'in a grid cell of i=',i,' j=',j,' k=',k
                    write(*,*)'is out of boundary'
                    write(*,*)'M/N=',rmnratio(i,j,k,isec)
                    write(*,*)'Mass (ug/m3) =',rmass(i,j,k,isec)
                    write(*,*)'Number (#/cm3) =',conc(i,j,k,lmod2)
                    STOP
                  endif
                enddo
             enddo
         enddo
       enddo


       return
       end

