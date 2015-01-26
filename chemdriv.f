      subroutine chemdriv(igrd,ncol,nrow,nlay,dt,itzon,idfin,fcloud,
     &                    cldtrns,water,tempk,press,height,cwc,conc,
     &                    cncrad,cellat,cellon,ldark,l3davg,
     &                    iptr2d,iptrsa,ipa_cel,Jnuc)
c
c-----CAMx v4.02 030709
c
c     CHEMDRIV performs chemistry on the current grid for one time step.
c     It calls one of two ODE solvers: TRAP or IEHSOLV.
c       TRAP    is the driver routine for the CMC fast solver.
c       IEHSOLV is the driver for an IEH solver 
c
c     Mechanism specific subroutines are passed to the driver routines.
c
c     Local array element con(nspec+1) is used to store the concentrations
c     of non-used species, i.e., species that are in the chem solver but
c     not on the species list for this run
c
c
c     Copyright 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003
c     ENVIRON International Corporation
c
c     Modifications:
c        1/9/02        A minor bug fix related to fast aero routine
c                      (units conversion)
c        1/15/02       Added code to handle RTRAC
c        01/30/02      Added code for RTRAC probing tool
c        10/18/02      Added CWC for aqueous PM chemistry
c        4/2/03        Removed option for UAM-V type cloud adjustment
c        03/21/03      Removed the OSAT technology type OPPAT
c
c     Input arguments:
c        igrd                grid index
c        ncol                number of columns
c        nrow                number of rows
c        nlay                number of layers
c        dt                  timestep (s)
c        itzon               time zone
c        idfin               map of nested grids in this grid
c        fcloud              cloud coverage (fraction)
c        cldtrns             energy transmission coefficient (fraction)
c        water               water vapor (ppm)
c        tempk               temperature (K)
c        press               pressure (mb)
c        height              layer interface height (m) 
c        cwc                 cloud water content (g/m3)
c        conc                species concentration (umol/m3)
c        cncrad              radical concentration (ppm)
c        cellat              cell centroid latitude (deg)
c        cellon              cell centroid longitude (deg)
c        ldark               darkness flag (T=dark)
c        l3davg              save 3-D average concentrations 
c        iptr2d              pointers into vectors for 2-D fields
c        iptrsa              pointers into vectors for tracer conc
c        ipa_cel             gridded array to identify if cell is
c                            in a IPRM sub-domain
c
c     Output arguments:
c        conc                species concentration (umol/m3)
c
c     Routines called:
c        KTHERM
c        GETZNTH
c        KPHOTO
c        TRAP
c        AEROCHEM
c        IEHSOLV
c
c     Called by:
c        CHEMRXN
c
      include 'camx.prm'
      include 'camx.com'
      include 'bndary.com'
      include 'chmstry.com'
      include 'filunit.com'
      include 'ahomap.com'
c
c======================== Process Analysis Begin =======================
c
      include 'procan.com'
c
c======================== Process Analysis End =========================
c
c
c======================== Source Apportion Begin =======================
c
      include "tracer.com"
c
c-----------------------------------------------------------------------
c  Local variables:
c-----------------------------------------------------------------------
c
      integer   ispc
      real      delo3, delno, delno2, delvoc, delh22, delhn3
      real      modo3, modnox, modvoc, o3old, o3new
      real      cold(MXTRSP), cnew(MXTRSP)
c
c========================= Source Apportion End ========================
c
c
c======================== DDM Begin =======================
c
      real      sddm(MXFDDM*MXSPEC)
c
c======================== DDM End =======================
c
c======================== Process Analysis Begin =======================
c
      integer ipa_cel(ncol,nrow,nlay)
      logical ldoirr, ldoipr
      real    rrxn_irr(MXRXN), patmp(MXTRSP)
      real    titrt
c
c======================== Process Analysis End =========================
c
c-----subroutine names to be called by TRAP and IEHSOLV
c
      external rxnrate1,radslvr1,ratejac1,rateslo1,ddmjac1
      external rxnrate2,radslvr2,ratejac2,rateslo2,ddmjac2
      external rxnrate3,radslvr3,ratejac3,rateslo3,ddmjac3
      external rxnrate4,radslvr4,ratejac4,rateslo4,ddmjac4
      external rxnrate5,radslvr5,ratejac5,rateslo5,ddmjac5
      external rxnrate6,radslvr6,ratejac6,rateslo6,ddmjac6
      external ierxn1, ierate1, iejac1, ieslow1
      external ierxn2, ierate2, iejac2, ieslow2
      external ierxn3, ierate3, iejac3, ieslow3
      external ierxn4, ierate4, iejac4, ieslow4
      external ierxn5, ierate5, iejac5, ieslow5
      external ierxn6, ierate6, iejac6, ieslow6
c
      logical l3davg,ldark(ncol,nrow),laero_upd
      real con(MXSPEC+1),crad(MXRADCL),avgrad(MXRADCL)
      real fcloud(ncol,nrow,nlay),cldtrns(ncol,nrow,nlay),
     &     water(ncol,nrow,nlay),tempk(ncol,nrow,nlay),
     &     press(ncol,nrow,nlay),height(ncol,nrow,nlay),
     &     cwc(ncol,nrow,nlay),conc(ncol,nrow,nlay,nspec),
     &     cellat(ncol,nrow),cellon(ncol,nrow),
     &     cncrad(ncol,nrow,nlay,MXRADCL)
      integer idfin(ncol,nrow)
c
      integer ii,jj,kk
      integer nsect,isp
c      integer ispc,naero
      integer order(nspec)
      integer iflag
      integer isund !check underbar
      real massum
      real massum2
      real frctn, nmbr
      real dsulfdt !sulfuric acid production rate
      real fndt(2) !nucleation diagnostic
      real Jnuc(ncol,nrow,nlay,2) !Common Nucleation Diagnostic
      integer inuc
c
c-----Entry point
c
cdbg      write(*,*)'At the beginning of chemdriv'
      call flush(6)
cdbg      write(*,*)'after flush(6) in chemdriv'
      call flush(iout)
c
cdbg      write(*,*)'In chemdriv, after flushing before time printing.' !dbg

      dtchem = dt/3600.
      con(nspec+1) = 0.
c
c     aero_tchk: current time (=time; HHMM)
c     grd_time : time to call aerosol routine (HHMM)
c     date_aer : simulation date (YYJJJ)
c     dtaero   : adjusted time interval between aerosol routines (min)
c     aero_dt  : actual time interval for each grid (hr) (accumulated dtchem)
      aero_tchk = time
      aero_dt(igrd) = aero_dt(igrd) + dtchem
      laero_upd = .false.
      if (idmech.eq.6) then ! bkoo_dbg
      write(*,*) 'aerotchk,grdtime: ',aero_tchk,grd_time(igrd)
      if ( (aero_tchk-grd_time(igrd)) .ge. -0.01 .and.
     &     (date .eq. date_aer(igrd)) ) then
        laero_upd = .true.
        write(*,*) 'Calling fullaero ... time: ',time,dtchem
     &                                          ,aero_dt(igrd)
      endif
      endif                 ! bkoo_dbg

cdbg      write(*,*)'In chemdriv, after time printing before ordering.'
c
c     For setting the order of conversion from con to conc by jgj 12/6/06
c     The order(kk) has a number of gas concentration first.
c     Then it saves mass concentrations at the first size bin.
c     Thereafter it saves number concentration at the size bin.
c     The order(kk) saves the order of species as the same way
c     as increasing the order of size bins.
c
      nsect = 43
      naero = 14
c
      do kk=1,ngas
         order(kk) = kk
      enddo

      kk=ngas

      do ii=1,nsect
         do jj=1,naero
            kk=kk+1
            if (jj.eq.naero) then
               order(kk) = ngas + (naero-1)*nsect + ii
            else
               order(kk) = ngas + (jj-1)*nsect + ii
            endif
         enddo
      enddo

cdbg      write(*,*)'In chemdriv, after advection species ordering, before
cdbg&checkconc' !dbg
cdbg      call checkconc(conc,ncol,nrow,nlay,nspc,species,4)
cdbg      write(*,*)'after checkconc in chemdriv'

c
      igrdchm = igrd
      do 91 k = 1,nlay
        write(*,*) 'Layer=',k
c
        do 90 j = 2,nrow-1
          i1 = 2
          i2 = ncol-1
          if (igrd.eq.1) then
            if (ibeg(j).eq.-999) goto 90
            i1=ibeg(j)
            i2=iend(j)
          endif
          do 89 i = i1,i2
            ichm = i
            jchm = j
            kchm = k
c
c-----skip chemistry if fine grid exists in this cell
c
            if (idfin(i,j).gt.igrd) goto 89
c
c-----For the gas phase species (numbered 1 to ngas)
c     Pass concentration to CON, converting from umol/m3 to ppm
cbk   Now SOA condensible gasses (CG) are in umol/m3 like other gases
c
            tcell = tempk(i,j,k)
            pcell = press(i,j,k)
            convfac = densfac*(273./tcell)*(pcell/1013.)
cbk            if (kcg1.ne.nspec+1) then
cbk              conc(i,j,k,kcg1) = conc(i,j,k,kcg1)*convfac
cbk              conc(i,j,k,kcg2) = conc(i,j,k,kcg2)*convfac
cbk              conc(i,j,k,kcg3) = conc(i,j,k,kcg3)*convfac
cbk              conc(i,j,k,kcg4) = conc(i,j,k,kcg4)*convfac
cbk            endif
            do is = 1,ngas
              con(is) = conc(i,j,k,is)/convfac
              if (con(is).lt.0.) then
                write(iout,'(//,a)') 'ERROR in CHEMDRIV:'
                write(iout,*) 'Negative concentration before chem'
                write(iout,*) 'igrd, i, j, k = ', igrd,i,j,k
                do l = 1,nspec
                  write(iout,'(i3,2x,a7,e10.3)') l,spname(l),con(l)
                enddo
                call camxerr()
              endif
              con(is) = amax1(bdnl(is),con(is))
            enddo
c
c-----Load any aerosols
c
            if (ngas.lt.nspec) then
              do is=ngas+1,nspec
                con(is) = conc(i,j,k,is)
                if (con(is).lt.0.) then
                  write(iout,'(//,a)') 'ERROR in CHEMDRIV:'
                  write(iout,*) 'Negative concentration before chem'
                  write(iout,*) 'igrd, i, j, k = ', igrd,i,j,k
                  do l = 1,nspec
                    write(iout,'(i3,2x,a7,e10.3)') l,spname(l),con(l)
                  enddo
                  call camxerr()
                endif
cjgj                con(is) = amax1(bdnl(is),con(is)) ! for conserving M/N ratios
              enddo
            endif
c
c-----Load radicals from last time step to use as initial guess
c
            do l=1,nrad
              crad(l) = cncrad(i,j,k,l)
            enddo
c
c-----Determine thermal rate constants
c
            call ktherm(tcell,pcell)
c
c-----Load local values of ozone, haze, albedo and zenith angle
c
            ij = i + (j-1)*ncol
            iozon = icdozn(iptr2d-1+ij)
            ihaze = icdhaz(iptr2d-1+ij)
            ialb = icdalb(iptr2d-1+ij)
            hght = height(i,j,k)/2000.
            if (k.gt.1)
     &        hght = (height(i,j,k) + height(i,j,k-1))/2000.
            if (cldtrns(i,j,k).ne.1.) then
              iabov = 0 
!              ctrns = cldtrns(i,j,k)
              fcld = fcloud(i,j,k)
            else
              iabov = 1
!              ctrns = cldtrns(i,j,1)
              fcld = fcloud(i,j,1)
            endif
            ctrns = cldtrns(i,j,k)
c           print *, 'Elham.Chemdrive.ctrns',ctrns
            call getznth(cellat(i,j),cellon(i,j),time,date,itzon,
     &                   zenith,ldark(i,j))
c
c-----Determine photolysis rates through interpolation of look-up table
c

c           print *,'Eli.ldark.chemdrive',ldark(i,j)

          
            call kphoto(iozon,ialb,ihaze,hght,zenith,fcld,
     &                  ctrns,ldark(i,j),iabov)

c          if (i.eq.145.and.j.eq.107.and.k.eq.13) then
c       write(*,*) 
c       print *,'Eli.chemdriv.i145.j107', rk 
c       print *,'Eli.hght',hght,'iozon',iozon,'ialb',ialb
c        print *,'Eli.chemdrive.zenth',zenith,'ctrns',ctrns
c       print *,'Eli.ldark:',ldark(i,j),'iabov',iabov
c        endif


c
c======================== Source Apportion Begin =======================
c
c  --- store the current value of the species needed for tracer "chemistry" ----
c
            if( ltrace )then
               if( tectyp .EQ. RTRAC ) then
                  do ispc=1,ngas
                     cold(ispc) = con(ispc)
                  enddo
                  o3old = con(ko3)
               else
                  delo3 = -con(ko3)*convfac
                  modo3 = con(ko3)*convfac
                  delno = -con(kno)*convfac
                  delno2 = -con(kno2)*convfac
                  modnox = con(kno)*convfac + con(kno2)*convfac
                  delh22 = -con(kh2o2)*convfac
                  delhn3 = -con(khno3)*convfac
                  delvoc = 0.
                  modvoc = 0.
                  do 10 ispc=1,ngas
                     if( lvocsp(ispc) ) then
                       delvoc = delvoc - con(ispc) * crbnum(ispc) * 
     &                                                        convfac
                       modvoc = modvoc + con(ispc) * crbnum(ispc) * 
     &                                                        convfac
                     endif
   10             continue
c
c  --- call routine to recalibrate so that tracer species stays
c      on track with model species: needed because the numerics
c      cause tracer species to drift
c
                  call recalib(ncol,nrow,nlay,ntotsp,ptconc(iptrsa),
     &                                       i,j,k,modo3,modnox,modvoc)
               endif
            endif
c
c========================= Source Apportion End ========================
c
c
c======================== DDM Begin ====================================
c
c  ---- load the sensitivities for this cell into 2-D array ---
c
            if (lddm) then
              call loaddm(.FALSE.,ncol,nrow,nlay,ntotsp,ptconc(iptrsa),
     &                    i,j,k,nddmsp,ngas,sddm,convfac)         
            endif
c
c
c======================== DDM End =======================================
c
c
c
c-----Chemistry integration, pass subroutines for mechanism used
c
            atm = 1.e6
            O2  = 2.095e5
            CH4 = 1.75
            H2  = 0.50
c
c======================== Process Analysis Begin =======================
c
            ldoipr = .FALSE.
            ldoirr = .FALSE.
            if( lproca ) then
               if( lipr .AND. ipa_cel(i,j,k) .GT. 0 )  then
                  ipa_idx = ipa_cel(i,j,k)
                  ldoipr = .TRUE.
               endif
               if( lirr ) then
                  if( ipa_cel(i,j,k) .GT. 0 ) then
                     ipa_idx = ipa_cel(i,j,k)
                     ldoirr = .TRUE.
                  endif
                  titrt = 0.0
                  do irxn=1,MXRXN
                     rrxn_irr(irxn) = 0.0
                  enddo
               endif
            endif
c
c======================== Process Analysis End =========================
c
            if ( idsolv .EQ. IDCMC ) then
               if (idmech.eq.1) then
                 call trap(rxnrate1,radslvr1,ratejac1,rateslo1,dtchem,
     &             ldark(i,j),water(i,j,k),atm,O2,CH4,H2,con,crad,
     &             avgrad,tcell,
     &             sddm,nddmsp,ngas,ddmjac2,lddm,nirrrxn,titrt,rrxn_irr,
     &             lirr)
               elseif (idmech.eq.2) then
                 call trap(rxnrate2,radslvr2,ratejac2,rateslo2,dtchem,
     &             ldark(i,j),water(i,j,k),atm,O2,CH4,H2,con,crad,
     &             avgrad,tcell,
     &             sddm,nddmsp,ngas,ddmjac2,lddm,nirrrxn,titrt,rrxn_irr,
     &             lirr)
               elseif (idmech.eq.3) then
                 call trap(rxnrate3,radslvr3,ratejac3,rateslo3,dtchem,
     &             ldark(i,j),water(i,j,k),atm,O2,CH4,H2,con,crad,
     &             avgrad,tcell,
     &             sddm,nddmsp,ngas,ddmjac3,lddm,nirrrxn,titrt,rrxn_irr,
     &             lirr)
               elseif (idmech.eq.4) then
                 call trap(rxnrate4,radslvr4,ratejac4,rateslo4,dtchem,
     &             ldark(i,j),water(i,j,k),atm,O2,CH4,H2,con,crad,
     &             avgrad,tcell,
     &             sddm,nddmsp,ngas,ddmjac4,lddm,nirrrxn,titrt,rrxn_irr,
     &             lirr)
                 call aerochem(water(i,j,k),tcell,pcell,cwc(i,j,k),con,
     &                                  convfac,dtchem,ldoipr,ipa_idx)
               elseif (idmech.eq.5) then
                 call trap(rxnrate5,radslvr5,ratejac5,rateslo5,dtchem,
     &             ldark(i,j),water(i,j,k),atm,O2,CH4,H2,con,crad,
     &             avgrad,tcell,
     &             sddm,nddmsp,ngas,ddmjac5,lddm,nirrrxn,titrt,rrxn_irr,
     &             lirr)
               elseif (idmech.eq.6) then
                 if (ldark(i,j)) then
                   nflag=0.0d0
                 else
                   nflag=1.0d0
                 endif
cdbg                 if ((ichm.eq.31).and.(jchm.eq.2).and.(kchm.eq.1)) then!dbg
cdbg                   print*,'before trap'
cdbg                   print*,'coordinate of (31,2,1)' !dbg
cdbg                   print*,'tempk,pressure,dsulfdt=',tempk(i,j,k)
cdbg     &                  ,pressure,dsulfdt !dbg
cdbg                 endif !dbg
                 call trap(rxnrate6,radslvr6,ratejac6,rateslo6,dtchem,
     &             ldark(i,j),water(i,j,k),atm,O2,CH4,H2,con,crad,
     &             avgrad,tcell,
     &             sddm,nddmsp,ngas,ddmjac6,lddm,nirrrxn,titrt,rrxn_irr,
     &             lirr,dsulfdt) ! to get sulfuric acid production rate
cjgj     &             lirr)
cdbg                 if ((i.eq.65).and.(j.eq.51).and.(k.eq.1)) then
cdbg                 if (k.eq.1) then
cdbg               call mnratios(conc,ncol,nrow,nlay,nspec,31) 
cdbg                 if ((ichm.eq.31).and.(jchm.eq.2).and.(kchm.eq.1)) then!dbg
cdbg                   print*,'after trap and before fullaero'
cdbg                   print*,'coordinate of (31,2,1)' !dbg
cdbg                   print*,'tempk,pressure,dsulfdt=',tempk,pressure
cdbg     &                  ,dsulfdt !dbg
cdbg                 endif !dbg


              

                 if ( laero_upd )
     &           call fullaero(water(i,j,k),tcell,pcell,cwc(i,j,k),
     &                         MXSPEC,MXRADCL,NSPEC,NGAS,
     &                         con,crad,convfac,time,aero_dt(igrd),
     &                         ichm,jchm,kchm,height,dsulfdt,fndt)
                 do inuc = 1,2
                   Jnuc(i,j,k,inuc) = fndt(inuc)
                 enddo

               endif
c
            elseif ( idsolv .EQ. IDIEH ) then
               if (idmech.eq.1) then
                   call iehsolv(ierxn1,ierate1,iejac1,ieslow1,
     &                  dtchem,water(i,j,k),atm,O2,CH4,H2,con,crad,
     &                  ldark(i,j),tcell,nirrrxn,rrxn_irr,lirr)
               elseif (idmech.eq.2) then
                   call iehsolv(ierxn2,ierate2,iejac2,ieslow2,
     &                  dtchem,water(i,j,k),atm,O2,CH4,H2,con,crad,
     &                  ldark(i,j),tcell,nirrrxn,rrxn_irr,lirr)
               elseif (idmech.eq.3) then
                   call iehsolv(ierxn3,ierate3,iejac3,ieslow3,
     &                  dtchem,water(i,j,k),atm,O2,CH4,H2,con,crad,
     &                  ldark(i,j),tcell,nirrrxn,rrxn_irr,lirr)
               elseif (idmech.eq.4) then
                   call iehsolv(ierxn4,ierate4,iejac4,ieslow4,
     &                  dtchem,water(i,j,k),atm,O2,CH4,H2,con,crad,
     &                  ldark(i,j),tcell,nirrrxn,rrxn_irr,lirr)
                   call aerochem(water(i,j,k),tcell,pcell,cwc(i,j,k),
     &                           con,convfac,dtchem,ldoipr,
     &                           ipa_idx)
               elseif (idmech.eq.5) then
                   call iehsolv(ierxn5,ierate5,iejac5,ieslow5,
     &                  dtchem,water(i,j,k),atm,O2,CH4,H2,con,crad,
     &                  ldark(i,j),tcell,nirrrxn,rrxn_irr,lirr)
               elseif (idmech.eq.6) then
                   call iehsolv(ierxn6,ierate6,iejac6,ieslow6,
     &                  dtchem,water(i,j,k),atm,O2,CH4,H2,con,crad,
     &                  ldark(i,j),tcell,nirrrxn,rrxn_irr,lirr)
                   if ( laero_upd )
     &             call fullaero(water(i,j,k),tcell,pcell,cwc(i,j,k),
     &                           MXSPEC,MXRADCL,NSPEC,NGAS,
     &                           con,crad,convfac,time,aero_dt(igrd),fndt)
               endif
c
            endif
c
            do l=1,nrad
              cncrad(i,j,k,l) = amax1(crad(l),bdlrad)
            enddo
c
c======================== Source Apportion Begin =======================
c
c  --- subtract the current values of the species from the before values
c      to get the delta values ---
c
            if( ltrace ) then
               delo3 = delo3 + AMAX1(bdnl(ko3),con(ko3)) * convfac
               delno = delno + AMAX1(bdnl(kno),con(kno)) * convfac
               delno2 = delno2 + AMAX1(bdnl(kno2),con(kno2)) * convfac
               delh22 = delh22 + AMAX1(bdnl(kh2o2),con(kh2o2)) * convfac
               delhn3 = delhn3 + AMAX1(bdnl(khno3),con(khno3)) * convfac
               do 20 ispc=1,ngas
                 if( lvocsp(ispc) ) then
                    delvoc = delvoc + amax1(bdnl(ispc),con(ispc)) * 
     &                                           crbnum(ispc) * convfac
                 endif
                 cnew(ispc) = con(ispc)
   20          continue
               o3new = AMAX1(bdnl(ko3),con(ko3))
c
c  --- call routine to do the tracer species "chemistry", just makes
c      adjustments for production or decay of the regular model species ----
c
               if( tectyp .EQ. OSAT ) then
                  call osatsa(ldark(i,j),igrd,i,j,k,
     &                  delo3,delno,delno2,delvoc,delh22,delhn3,dtchem)
               else if( tectyp .EQ. GOAT ) then
                  call goatsa(ldark(i,j),igrd,i,j,k,
     &                               delo3,delno,delno2,delvoc,dtchem)
               else if( tectyp .EQ. APCA ) then
                  call apcasa(ldark(i,j),igrd,i,j,k,
     &                  delo3,delno,delno2,delvoc,delh22,delhn3,dtchem)
               else if( tectyp .EQ. RTRAC ) then
                  if( ipa_cel(i,j,k) .GT. 0 )  then
                       irt_cel = ipa_cel(i,j,k)
                  else
                       irt_cel = -9
                  endif
                  call chemrt(igrd,i,j,k,pcell,tcell,cold,cnew,
     &                 avgrad(koh),(o3old+o3new)/2,avgrad(kno3),dtchem,
     &                 convfac,irt_cel)
               endif
            endif
c
c========================= Source Apportion End ========================
c
c
c========================= DDM Begin ===================================
c
c  --- put the changed values back into the gridded array ---
c
            if (lddm) then
              call loaddm(.TRUE.,ncol,nrow,nlay,ntotsp,ptconc(iptrsa),
     &                    i,j,k,nddmsp,ngas,sddm,convfac)         
            endif
c
c========================= DDM End =====================================
c
c
c======================= Process Analysis Begin ========================
c
            if( ldoipr ) then
c
c --- Chemistry change in umol/m3 units ----
c
               do is=1,ngas
                  cipr(IPR_CHEM, ipa_idx, is) =
     &               cipr(IPR_CHEM, ipa_idx, is) +
     &                  con(is)*convfac-conc(i,j,k,is)
               enddo
            endif
c
c --- Chemical reaction tracking in ppm units
c     Account for titration reaction in TRAP at night ---
c
            if( ldoirr ) then
              do irxn=1,nirrrxn
                cirr(ipa_idx, irxn) =
     &                   cirr(ipa_idx, irxn) + rrxn_irr(irxn)
              enddo
              if ( titrt .GT. 0.0 ) then
                if ( idmech.EQ.5) then
                  cirr(ipa_idx, 5) =
     &                     cirr(ipa_idx, 5) + titrt
                else
                  cirr(ipa_idx, 3) =
     &                     cirr(ipa_idx, 3) + titrt
                endif
              endif
            endif
c
c   --- calculate the gridded chemical mechanism data ---
c
            if( lirr .AND. (l3davg .OR. k .EQ. 1) ) then
               if(idmech .EQ. 3) then
                 call cpamech3(rrxn_irr,MXRXN,patmp,ntotsp,nn)
               elseif(idmech .EQ. 5) then
                 call cpamech5(rrxn_irr,MXRXN,patmp,ntotsp,nn)
               endif
c    
c  --- save radical concentrations ---
c
               if( .NOT. lcpacum)
     &           call cparad(crad, nrad, patmp, ntotsp, nn, dtchem)
c
c  --- add CPA values to gridded array in native units ---    
c
               do l=1,ntotsp
                 idx = i + ncol*(j-1) + ncol*nrow*(k-1) +
     &                                         ncol*nrow*nlay*(l-1)
                 ptconc(iptrsa-1+idx) = ptconc(iptrsa-1+idx) + patmp(l)
               enddo
            endif
c
c======================== Process Analysis End =========================
c
c-----Pass CON back to concentration, convert gases from ppm to umol/m3
cbk   Now SOA condensible gasses (CG) are in umol/m3 like other gases
c
cbk            if (kcg1.ne.nspec+1) then
cbk              con(kcg1) = con(kcg1)/convfac
cbk              con(kcg2) = con(kcg2)/convfac
cbk              con(kcg3) = con(kcg3)/convfac
cbk              con(kcg4) = con(kcg4)/convfac
cbk            endif
            do is=1,ngas
              con(is) = amax1(bdnl(is),con(is)) ! bkoo (03/12/03)
              conc(i,j,k,is) = con(is)*convfac
            enddo
c
c       In case a con is less than bdnl, the fraction of difference 
c       between con and bdnl to the total mass at the size bin will be 
c       multiplied by the number concentration at the bin, then it will 
c       be added to the number concentration. This is to avoid setting
c       very tiny values to con so that we do not have M/N ratio 
c       problem in TOMAS.
c                                                  12/6/06 jgj
c
c     added by LA
            do is=1,nspec
               if(con(is).lt.1.0e-37) then
                  con(is)=1.0e-37
               endif
            enddo
c     end LA
            if (ngas.lt.nspec) then
              ispc=ngas
              do ii=1,nsect
                 isp = ispc
                 massum = 0  ! old mass sum
                 massum2 = 0 ! new mass sum
                 do jj=1,naero
                    ispc = ispc + 1
                    is = order(ispc)
                    if (jj.le.naero-1) then
                      ! To avoid number conc.
                      isund=INDEX(spname(is),'_')
                      if (spname(is)(1:isund-1).ne.'PH2O') then ! To avoid H2O
                         massum = massum + con(is)
cdbg                         if ((time.gt.0.).and.(time.lt.30.))then
cdbg                         if ((i.eq.36).and.(j.eq.29).and.(k.eq.1))then
cdbg                            write(*,*)'Coord=',i,j,k
cdbg                            write(*,*)'species=',spname(is)
cdbg                            write(*,*)'con',con(is)
cdbg                         endif
cdbg                         endif
                      endif
                    endif
c     added by LA
c                    if(i.le.2 .and. j.le.2 .and. k.le.1) then
c                       write(*,*)
c                       write(*,*)'isund=',INDEX(spname(is),'_')
c                       write(*,*)'is=',is
c                       write(*,*)'spname(is)(1:isund-1)=',
c     &                      spname(is)(1:isund-1)
c                       write(*,*)'con(is)=',con(is)
c                       write(*,*)'massum=',massum
c                    endif
c     end LA
                 enddo
                 ispc = isp
                 inum = order(ispc+naero)
                 nmbr = con(inum)
                 frctn = 0.
                 do jj=1,naero
                    ispc = ispc + 1
                    is = order(ispc)
                    if (con(is).lt.bdnl(is)) then
cdbg                      if ((time.gt.0.).and.(time.lt.30.))then
cdbg                        if ((i.eq.36).and.(j.eq.29).and.(k.eq.1))then
cdbg                          write(*,*)'Coord=',i,j,k
cdbg                          write(*,*)'species=',spname(is)
cdbg                          write(*,*)'con is less than bdnl.'
cdbg                          write(*,*)'con',con(is)
cdbg                          write(*,*)'bdnl=',bdnl(is)
cdbg                          write(*,*)'con(inum)=',con(inum)
cdbg                          iflag=1
cdbg                        endif
cdbg                      endif
                      con(is)=bdnl(is)
                    endif
                    if (jj.le.naero-1) then
                       ! To avoid number conc.
                      isund=INDEX(spname(is),'_')
                      if (spname(is)(1:isund-1).ne.'PH2O') then ! To avoid H2O
                         massum2 = massum2 + con(is)
                      endif
                    endif
                 enddo
                 frctn=massum2/massum
                 con(inum)=nmbr*frctn
cdbg                 if (iflag.eq.1) then
cdbg                   write(*,*)'con(inum)=',con(inum)
cdbg                   write(*,*)'massum=',massum
cdbg                   write(*,*)'massum2=',massum2
cdbg                   write(*,*)'frctn=',frctn
cdbg                   iflag = 0
cdbg                 endif
              enddo
              
              do is=ngas+1,nspec
cjgj                conc(i,j,k,is) = amax1(con(is),bdnl(is))
                conc(i,j,k,is) = con(is)
              enddo
            endif
c     added by LA
c            if(i.le.2 .and. j.le.2 .and. k.le.1) then
c               write(*,*)
c               write(*,*)'con aft fullaero and spec2=',con
c            endif
c     end LA
c
  89      continue
  90    continue
c
  91  continue
c
c     if fullaero was called
c     - reset aero_dt 
c     - increase grd_time (& date_aer) by dtaero (or multiple of dtaero)
      if (laero_upd) then
        aero_dt(igrd) = 0.0
        call uptime(grd_time(igrd),date_aer(igrd),60.*dtaero)
        gtime = grd_time(igrd)
        idate = date_aer(igrd)
  92    call uptime(gtime,idate,60.*dtaero)
        if ( gtime .le. time .and. idate .eq. date ) then
          grd_time(igrd) = gtime
          date_aer(igrd) = idate
        else
          goto 93
        endif
        goto 92
      endif
  93  continue
c     added by LA
c      write(*,*)'end of chemdriv; conc(2,2,1,:) =',conc(2,2,1,:)
c     end LA
c
      return
      end
