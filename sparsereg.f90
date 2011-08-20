      MODULE SPARSEREG
!
!     Determine double precision and set constants.
!
      IMPLICIT NONE
      INTEGER , PARAMETER :: DBLE_PREC = KIND (0.0D0)
      REAL (KIND=DBLE_PREC), PARAMETER :: ZERO  = 0.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: ONE   = 1.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: TWO   = 2.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: THREE = 3.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: FOUR  = 4.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: FIVE  = 5.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: SIX   = 6.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: SEVEN = 7.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: EIGHT = 8.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: NINE  = 9.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: TEN   = 10.0_DBLE_PREC
      REAL (KIND=DBLE_PREC), PARAMETER :: HALF  = ONE/TWO
      REAL (KIND=DBLE_PREC), PARAMETER :: PI    = 3.14159265358979_DBLE_PREC
!
      CONTAINS
!
      SUBROUTINE LOG_PENALTY(BETA,RHO,ETA,PEN,D1PEN,D2PEN,DPENDRHO)
!
!     This subroutine calculates the penalty value, first derivative, 
!     and second derivatives of the log penalty: RHO*LOG(ETA+ABS(BETA)) for
!     eta>0 or RHO*LOG(SQRT(RHO)+ABS(BETA)) for eta=0
!
      IMPLICIT NONE
      REAL(KIND=DBLE_PREC) :: ETA,RHO
      REAL(KIND=DBLE_PREC), DIMENSION(:) :: BETA
      REAL(KIND=DBLE_PREC), DIMENSION(:) :: PEN
      REAL(KIND=DBLE_PREC), OPTIONAL, DIMENSION(:) :: D1PEN,D2PEN,DPENDRHO
!
!     Local variable
!
      LOGICAL :: CONTLOG=.FALSE.
!
!     Check nonnegativity of tuning parameter
!
      IF (RHO<ZERO) THEN
         !PRINT*,"THEN TUNING PARAMETER MUST BE NONNEGATIVE."
         RETURN
      END IF
!
!     Use continuous log penalty if eta=0
!
      IF (ETA==ZERO) THEN
         ETA = SQRT(RHO)
         CONTLOG = .TRUE.
      END IF
!
!     Penalty values
!
      PEN = RHO*LOG(ETA+ABS(BETA))
!
!     First derivative of penalty function
!
      IF (PRESENT(D1PEN)) THEN
         D1PEN = RHO/(ETA+ABS(BETA))
      END IF
!
!     Second derivative of penalty function
!
      IF (PRESENT(D2PEN)) THEN
         D2PEN = -D1PEN/(ETA+ABS(BETA))
      END IF
!
!     Second mixed derivative of penalty function
!
      IF (PRESENT(DPENDRHO)) THEN
         DPENDRHO = ONE/(ETA+ABS(BETA))
         IF (CONTLOG) THEN
            DPENDRHO = DPENDRHO*(ONE-HALF*ETA*DPENDRHO)
         END IF
      END IF
      END SUBROUTINE
!
      FUNCTION LOG_THRESHOLDING(A,B,RHO,ETA)
!
!     This subroutine performs univariate soft thresholding with log penalty:
!     min .5*a*x^2+b*x+rho*log(eta+x). Input with eta=0 implies using
!     eta=sqrt(rho), i.e., continuous log penalty.
!
      IMPLICIT NONE
      REAL(KIND=DBLE_PREC) :: A,B,ETA,F1,F2,LOG_THRESHOLDING,RHO
!
!     Check inputs
!      
      IF (ETA<ZERO) THEN
         !PRINT *, "PARAMETER ETA FOR LOG PENALTY SHOULD BE POSITIVE"
         RETURN
      ELSE IF (ETA==ZERO) THEN
         ETA = SQRT(RHO)
      END IF
!
!     Transform to format 0.5*a*(x-b)^2 + rho*log(eta+abs(x))
!
      IF (A<=ZERO) THEN
         !PRINT *, "QUADRATIC COEFFICIENT A MUST BE POSITIVE"
         RETURN
      END IF
      B = -B/A
!
!     Thresholding
!
      IF (RHO>=A*(ETA+ABS(B))**2/FOUR) THEN
         LOG_THRESHOLDING = ZERO
      ELSE IF (RHO<=ABS(A*B*ETA)) THEN
         LOG_THRESHOLDING = SIGN(HALF*(ABS(B)-ETA+ &
            SQRT((ABS(B)+ETA)**2-FOUR*RHO/A)),B)
      ELSE
         LOG_THRESHOLDING = SIGN(HALF*(ABS(B)-ETA+ &
            SQRT((ABS(B)+ETA)**2-FOUR*RHO/A)),B)
         F1 = HALF*A*B*B+RHO*LOG(ETA)
         F2 = HALF*A*(LOG_THRESHOLDING-B)**2+RHO*LOG(ETA+ABS(LOG_THRESHOLDING))
         IF (F1<F2) THEN
            LOG_THRESHOLDING = ZERO
         END IF
      END IF
      END FUNCTION LOG_THRESHOLDING
!
      FUNCTION MAX_RHO(A,B,PENTYPE,PENPARAM) RESULT(MAXRHO)
!
!     This subroutine finds the maximum penalty constant rho such that
!     argmin 0.5*A*x^2+B*x+penalty(x,rho) is nonzero. Current options for
!     PENTYPE are "LOG","SCAD","MCP","POWER". PENPARAM contains the
!     optional parameter for the penalty function.
!
      CHARACTER(LEN=*), INTENT(IN) :: PENTYPE
      REAL(KIND=DBLE_PREC) :: A,B,EPS=1E-6,L,M,MAXRHO,R,ROOTL,ROOTM,ROOTR
      REAL(KIND=DBLE_PREC), DIMENSION(:) :: PENPARAM
!
!     Set search interverl for rho
!
      SELECT CASE(PENTYPE)
      CASE("LOG")
         IF (PENPARAM(1)==ZERO) THEN
            IF (A<=ONE) THEN
               MAXRHO = A*A*B*B
               RETURN
            ELSE
               L = A*A*B*B
               R = TWO*L
               DO WHILE(LOG_THRESHOLDING(A,B,R,PENPARAM(1))>ZERO)
                  L = R
                  R = TWO*R
               END DO
            END IF
         ELSE
            L = ABS(A*B*PENPARAM(1))
            R = A*(PENPARAM(1)+ABS(B))**2/FOUR
         END IF
      CASE("SCAD")
      CASE("MCP")
      CASE("ENET")
      CASE("POWER")
      END SELECT
!
!     Bisection search
!
      ROOTL = LOG_THRESHOLDING(A,B,L,PENPARAM(1))
      ROOTR = LOG_THRESHOLDING(A,B,R,PENPARAM(1))
      DO
         M = HALF*(L+R)
         SELECT CASE(PENTYPE)
         CASE("LOG")
            ROOTM = LOG_THRESHOLDING(A,B,M,PENPARAM(1))
         CASE("SCAD")
         CASE("MCP")
         CASE("ENET")
         CASE("POWER")
         END SELECT
         IF (ROOTM==ZERO) THEN
            R = M
            ROOTR = ROOTM
         ELSE
            L = M
            ROOTL = ROOTM
         END IF
         IF (ABS(R-L)<EPS) THEN
            MAXRHO = M
            EXIT
         END IF
      END DO
      END FUNCTION MAX_RHO
!
      SUBROUTINE PENALIZED_L2_REGRESSION(ESTIMATE,X,Y,WT,LAMBDA, &
         SUM_X_SQUARES,PENIDX,MAXITERS,PENTYPE,PENPARAM)
!
!     This subroutine carries out penalized L2 regression with design
!     matrix X, dependent variable Y, weights W and penalty constant 
!     LAMBDA. Note that the rows of X correspond to cases and the columns
!     to predictors.  The SUM_X_SQUARES should have entries SUM(W*X(:,I)**2)
!
      IMPLICIT NONE
      CHARACTER(LEN=*), INTENT(IN) :: PENTYPE
      INTEGER :: I,ITERATION,M,MAXITERS,N
      REAL(KIND=DBLE_PREC) :: CRITERION=TEN**(-4),EPS=TEN**(-8)
      REAL(KIND=DBLE_PREC) :: A,B,LAMBDA,NEW_OBJECTIVE,OLDROOT
      REAL(KIND=DBLE_PREC) :: OBJECTIVE,ROOTDIFF
      LOGICAL, DIMENSION(:) :: PENIDX
      REAL(KIND=DBLE_PREC), DIMENSION(:) :: ESTIMATE,PENPARAM,SUM_X_SQUARES,WT,Y
      REAL(KIND=DBLE_PREC), DIMENSION(:,:) :: X
      LOGICAL, DIMENSION(SIZE(ESTIMATE)) :: NZIDX
      REAL(KIND=DBLE_PREC), DIMENSION(SIZE(Y)) :: R
      REAL(KIND=DBLE_PREC), DIMENSION(SIZE(ESTIMATE)) :: PENALTY
!
!     Check that the number of cases is well defined.
!
      IF (SIZE(Y)/=SIZE(X,1)) THEN
         !PRINT*," THE NUMBER OF CASES IS NOT WELL DEFINED."
         RETURN
      END IF
!
!     Check that the number of predictors is well defined.
!
      IF (SIZE(ESTIMATE)/=SIZE(X,2)) THEN
         !PRINT*, " THE NUMBER OF PREDICTORS IS NOT WELL DEFINED."
         RETURN
      END IF
!
!     Check the index for penalized predictors
!
      IF (SIZE(PENIDX)/=SIZE(X,2)) THEN
         !PRINT*, " THE PENALTY INDEX ARRAY IS NOT WELL DEFINED"
         RETURN
      END IF
!
!     Initialize the number of cases M and the number of regression
!     coefficients N.
!
      M = SIZE(Y)
      N = SIZE(ESTIMATE)
!
!     Initialize the residual vector R, the PENALTY, the loss L2, and the
!     objective function.
!
      IF (ANY(ABS(ESTIMATE)>EPS)) THEN
         R = Y-MATMUL(X,ESTIMATE)
      ELSE
         R = Y
      END IF
      SELECT CASE(PENTYPE)
      CASE("LOG")
         CALL LOG_PENALTY(ESTIMATE,LAMBDA,PENPARAM(1),PENALTY)
      END SELECT
      OBJECTIVE = HALF*SUM(WT*R**2)+SUM(PENALTY,PENIDX)
!
!     Initialize maximum number of iterations
!
      IF (MAXITERS<=0) THEN
         MAXITERS = 1000
      END IF
!
!     Enter the main iteration loop.
!
      DO ITERATION = 1,MAXITERS
         DO I = 1,N
            OLDROOT = ESTIMATE(I)           
            A = SUM_X_SQUARES(I)
            B = - SUM(WT*R*X(:,I)) - A*OLDROOT
            IF (PENIDX(I)) THEN
               SELECT CASE(PENTYPE)
               CASE("LOG")
                  ESTIMATE(I) = LOG_THRESHOLDING(A,B,LAMBDA,PENPARAM(1))
               CASE("SCAD")
               CASE("MCP")
               CASE("ENET")
               CASE("POWER")
               END SELECT
            ELSE
               ESTIMATE(I) = -B/A
            END IF
            ROOTDIFF = ESTIMATE(I)-OLDROOT
            IF (ABS(ROOTDIFF)>EPS) THEN
                   R = R - ROOTDIFF*X(:,I)
            END IF
         END DO
!
!     Output the iteration number and value of the objective function.
!
         SELECT CASE(PENTYPE)
         CASE("LOG")
            CALL LOG_PENALTY(ESTIMATE,LAMBDA,PENPARAM(1),PENALTY)
         CASE("SCAD")
         CASE("MCP")
         CASE("ENET")
         CASE("POWER")
         END SELECT
         NEW_OBJECTIVE = HALF*SUM(WT*R**2)+SUM(PENALTY,PENIDX)
         IF (ITERATION==1.OR.MOD(ITERATION,1)==0) THEN
            !PRINT*," ITERATION = ",ITERATION," FUN = ",NEW_OBJECTIVE
         END IF
!
!     Check for a descent failure or convergence.  If neither occurs,
!     record the new value of the objective function.
!
         IF (NEW_OBJECTIVE>OBJECTIVE+EPS) THEN
            !PRINT*," *** ERROR *** OBJECTIVE FUNCTION INCREASE AT ITERATION",ITERATION
            RETURN
         END IF
         IF ((OBJECTIVE-NEW_OBJECTIVE)<CRITERION*(ABS(OBJECTIVE)+ONE)) THEN
            RETURN
         ELSE
            OBJECTIVE = NEW_OBJECTIVE
         END IF
      END DO
      END SUBROUTINE PENALIZED_L2_REGRESSION
!
      END MODULE SPARSEREG