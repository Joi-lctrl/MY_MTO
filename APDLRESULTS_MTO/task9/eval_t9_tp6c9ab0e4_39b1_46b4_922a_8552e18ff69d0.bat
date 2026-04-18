FINISH  
/CLEAR, START   
/TITLE, Task9_opt   
/NOPR   
RESUME, task9_base_model, db
/PREP7  
    
SECTYPE, 1, BEAM, I, LONG_1, 5  
SECDATA, 145.779, 2400, 334.045, 16.1925, 12, 5.24478   
SECTYPE, 2, BEAM, I, LONG_2, 5  
SECDATA, 204.153, 2400, 516.137, 18.0304, 12, 9.65714   
SECTYPE, 3, BEAM, I, LONG_3, 5  
SECDATA, 138.75, 2400, 414.227, 19.7696, 12, 9.24834
SECTYPE, 4, BEAM, I, LONG_4, 5  
SECDATA, 220, 1800, 417.214, 15.4124, 12, 8.37338   
SECTYPE, 5, BEAM, I, RIB, 5 
SECDATA, 176.243, 1800, 545.243, 14.6193, 12, 6.59569   
    
FINISH  
FINISH  
/SOLU   
ANTYPE, STATIC  
OUTRES, ALL, LAST   
OUTRES, MISC, LAST  
SOLVE   
FINISH  
    
/POST1  
SET, LAST   
/ESHAPE, 1  
    
*GET, sx_max, SECR, ALL, S, X, MAX  
*GET, sx_min, SECR, ALL, S, X, MIN  
*GET, sxy_max, SECR, ALL, S, XY, MAX
*GET, sxy_min, SECR, ALL, S, XY, MIN
*GET, sxz_max, SECR, ALL, S, XZ, MAX
*GET, sxz_min, SECR, ALL, S, XZ, MIN
    
max_bend = ABS(sx_max)  
*IF,ABS(sx_min),GT,max_bend,THEN
	max_bend = ABS(sx_min) 
*ENDIF  
    
max_shear = ABS(sxy_max)
*IF,ABS(sxy_min),GT,max_shear,THEN  
	max_shear = ABS(sxy_min)   
*ENDIF  
*IF,ABS(sxz_max),GT,max_shear,THEN  
	max_shear = ABS(sxz_max)   
*ENDIF  
*IF,ABS(sxz_min),GT,max_shear,THEN  
	max_shear = ABS(sxz_min)   
*ENDIF  
    
*STATUS,max_bend
*STATUS,max_shear   
    
*CFOPEN, eval_t9_tp6c9ab0e4_39b1_46b4_922a_8552e18ff69d_results, txt
*VWRITE, sx_max 
(F20.6) 
*VWRITE, sx_min 
(F20.6) 
*VWRITE, sxy_max
(F20.6) 
*VWRITE, sxy_min
(F20.6) 
*VWRITE, sxz_max
(F20.6) 
*VWRITE, sxz_min
(F20.6) 
    
! Total structural mass from FEA model  
ALLSEL, ALL 
*GET, total_mass, ELEM, 0, MTOT, Z  
*VWRITE, total_mass 
(E20.10)
*CFCLOS 
FINISH  
