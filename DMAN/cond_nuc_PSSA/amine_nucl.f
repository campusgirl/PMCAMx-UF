
C     **************************************************
C     *  amine_nucl                                     *
C     **************************************************

C     WRITTEN BY Jan and Ben, October 2014

C     This subroutine calculates the ternary nucleation rate and radius of the 
C     critical nucleation cluster using the parameterization of...

c     Napari, I., M. Noppel, H. Vehkamaki, and M. Kulmala. "Parametrization of 
c     Ternary Nucleation Rates for H2so4-Nh3-H2o Vapors." Journal of Geophysical 
c     Research-Atmospheres 107, no. D19 (2002).

      SUBROUTINE amine_nucl(tempi,csi,cnai,dma_i,fn,rnuc)

      IMPLICIT NONE
 
      include 'sizecode.COM'

C-----INPUTS------------------------------------------------------------

      real tempi                            ! temperature of air [K]
      double precision csi                  ! condensation sink [s-1]
      double precision cnai                 ! concentration of gas phase sulfuric acid [molec cm-3]
      double precision dma_i                ! concentration of dimethyl amine [ppt]

C-----OUTPUTS-----------------------------------------------------------

      double precision fn                   ! nucleation rate [cm-3 s-1]
      double precision rnuc                 ! critical cluster radius [nm]
c      double precision tonset

C-----INCLUDE FILES-----------------------------------------------------

C-----ARGUMENT DECLARATIONS---------------------------------------------

C-----VARIABLE DECLARATIONS---------------------------------------------

      double precision fnl                  ! natural log of nucleation rate
      double precision tmp                  ! temperature of air [K]
      double precision cs                   ! condensation sink [s-1]
      double precision cna                  ! concentration of gas phase sulfuric acid [molec cm-3]
      double precision dma                  ! concentration of gas phase dimethyl amine [ppt]
c
      integer ii                 ! counter
      real    ii1, ii2, ii3, ii4
      real    ic1, ic2, ic3, ic4
      integer itemp, ics, icna, idma
      integer itemp1,ics1,icna1,idma1


C
      tmp  = tempi  !K
      cs   = csi    !s-1
      cna  = cnai   !molec cm-3
      dma  = dma_i  !molec cm-3
       
      !Limit All Values to Upper Bound on Lookup Table
      tmp = max(min(tmp,320.0),180.0)
      cs   = max(min(cs,2.0e-1),1.0e-5)
      cna  = max(min(cna,3.16e9),1.e4)
      dma  = max(min(dma,1.0e9),1.e4)

      !Locate the lower-bound indices of all the 
      !independent variables
      call locate(amine_nuc_tbl_TEMP,  amine_nuc_nTEMP, tmp, itemp)
      call locate(amine_nuc_tbl_CS,    amine_nuc_nCS, cs, ics)
      call locate(amine_nuc_tbl_H2SO4, amine_nuc_nH2SO4, cna, icna)
      call locate(amine_nuc_tbl_DMA,   amine_nuc_nDMA, dma, idma)

      !Define Nearest Neighbors for Each Index
      itemp1 = itemp + 1
      ics1   = ics   + 1
      icna1  = icna  + 1
      idma1  = idma  + 1

      !Use Multilinear Interpolation even though it is a rather coarse,
      !inaccurate method
      ii1  =  (tmp - amine_nuc_tbl_TEMP(itemp)) / 
     &        (amine_nuc_tbl_TEMP(itemp1) - amine_nuc_tbl_TEMP(itemp) )
      ii2  =  (log10(cs) - log10(amine_nuc_tbl_CS(ics))) / 
     &        (log10(amine_nuc_tbl_CS(ics1)) - log10(amine_nuc_tbl_CS(ics)) )
      ii3  =  (log10(cna) - log10(amine_nuc_tbl_H2SO4(icna))) / 
     &        (log10(amine_nuc_tbl_H2SO4(icna1)) - log10(amine_nuc_tbl_H2SO4(icna)) )
      ii4  =  (log10(dma) - log10(amine_nuc_tbl_DMA(idma))) / 
     &        (log10(amine_nuc_tbl_DMA(idma1)) - log10(amine_nuc_tbl_DMA(idma)) )
      !Store the complements of these factors
      ic1  = 1 - ii1
      ic2  = 1 - ii2
      ic3  = 1 - ii3
      ic4  = 1 - ii4

      !Combine Contributions in all four dimensions to yield
      !Nucleation Rate [particles cm-3 s-1]
      rnuc = ic1*ic2*ic3*ic4*amine_nuc_tbl_J(itemp, ics, icna, idma) +
     &       ii1*ic2*ic3*ic4*amine_nuc_tbl_J(itemp1,ics, icna, idma) +
     &       ic1*ii2*ic3*ic4*amine_nuc_tbl_J(itemp, ics1,icna, idma) +
     &       ii1*ii2*ic3*ic4*amine_nuc_tbl_J(itemp1,ics1,icna, idma) +
     &       ic1*ic2*ii3*ic4*amine_nuc_tbl_J(itemp, ics, icna1,idma) +
     &       ii1*ic2*ii3*ic4*amine_nuc_tbl_J(itemp1,ics, icna1,idma) +
     &       ic1*ii2*ii3*ic4*amine_nuc_tbl_J(itemp, ics1,icna1,idma) +
     &       ii1*ii2*ii3*ic4*amine_nuc_tbl_J(itemp1,ics1,icna1,idma) +
     &       ic1*ic2*ic3*ii4*amine_nuc_tbl_J(itemp, ics, icna, idma1) +
     &       ii1*ic2*ic3*ii4*amine_nuc_tbl_J(itemp1,ics, icna, idma1) +
     &       ic1*ii2*ic3*ii4*amine_nuc_tbl_J(itemp, ics1,icna, idma1) +
     &       ii1*ii2*ic3*ii4*amine_nuc_tbl_J(itemp1,ics1,icna, idma1) +
     &       ic1*ic2*ii3*ii4*amine_nuc_tbl_J(itemp, ics, icna1,idma1) +
     &       ii1*ic2*ii3*ii4*amine_nuc_tbl_J(itemp1,ics, icna1,idma1) +
     &       ic1*ii2*ii3*ii4*amine_nuc_tbl_J(itemp, ics1,icna1,idma1) +
     &       ii1*ii2*ii3*ii4*amine_nuc_tbl_J(itemp1,ics1,icna1,idma1)
      
      return

      end subroutine

!=============================================================
!
      subroutine read_amine_nuc_table
c
c
c     read_amine_nuc_table opens the lookup table for amine-sulfuric
c     acid nucleation and reads in the table values
c
c     Written: Ben Murphy and Jan Julin 10/17/14
c
c     Input arguments: 
c        none 
c 
c     Output arguments: 
c        All captured variables go to common block in sizecode.COM
c        amine_nuc_tbl_H2SO4 - sulfuric acid conc. [molec cm-3]
c        amine_nuc_tbl_DMA   - dimethyl amine conc. [moelc cm-3??]
c                                  check this!! --------^
c        amine_nuc_tbl_CS    - condensaiton sink [s-1]
c        amine_nuc_tbl_TEMP  - temperature [K]
c        amine_nuc_tbl_J     - Nucleation Rate [Particles cm-3 s-1]
c            
c     Called by:
c        CHMPREP
c
      include 'sizecode.COM'
c
      integer iH2SO4, iDMA, iCS, iTEMP

      open(unit=98,file='DMAN/cond_nuc_PSSA/ACDC_H2SO4_DMA_05Feb2014.txt')

      !First read header and toss it
      read (98, *)

      !Now Start Reading in the Table
      do iTEMP = 1,amine_nuc_nTEMP
        do iCS = 1,amine_nuc_nCS
          do iH2SO4 = 1,amine_nuc_nH2SO4
            do iDMA = 1,amine_nuc_nDMA
	      read (98,*) amine_nuc_tbl_H2SO4(iH2SO4), amine_nuc_tbl_DMA(iDMA),
     &                    amine_nuc_tbl_TEMP(iTEMP),   amine_nuc_tbl_CS(iCS),
     &                    amine_nuc_tbl_J(iTEMP, iCS, iH2SO4, iDMA)
            enddo
          enddo
        enddo
      enddo

      close(98)

      return

      end subroutine

c========================================================
c
      SUBROUTINE locate(xx,n,x,j)
c     Lookup the nearest index (j) in the array xx to the
c     value, x, where xx is of length n. x will be
c     between xx(j) and xx(j+1).
c
c========================================================
      IMPLICIT NONE

      INTEGER j,n
      REAL x,xx(n)
      INTEGER jl,jm,ju
      jl=0
      ju=n+1
10    if(ju-jl.gt.1)then
        jm=(ju+jl)/2
        if((xx(n).ge.xx(1)).eqv.(x.ge.xx(jm)))then
          jl=jm
        else
          ju=jm
        endif
      goto 10
      endif
      if(x.eq.xx(1))then
        j=1
      else if(x.eq.xx(n))then
        j=n-1
      else
        j=jl
      endif
      return
      END 