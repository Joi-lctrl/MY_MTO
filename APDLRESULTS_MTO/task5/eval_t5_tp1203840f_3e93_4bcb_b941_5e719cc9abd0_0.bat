FINISH  
/CLEAR, START   
/TITLE, Task5_opt   
/NOPR   
RESUME, task5_base_model, db
/PREP7  
    
SECTYPE, 1, BEAM, I, LONG_C, 5  
SECDATA, 181.974, 133, 404.226, 12.3792, 12, 7.40527
SECTYPE, 2, BEAM, I, LONG_S, 5  
SECDATA, 116.778, 133, 474.371, 12.7051, 12, 8.35393
SECTYPE, 4, BEAM, I, LONG_O, 5  
SECDATA, 116.778, 133, 474.371, 12.7051, 12, 8.35393
SECTYPE, 3, BEAM, I, RIB, 5 
SECDATA, 79.8761, 400, 174.164, 6.75544, 12, 6.51358
    
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
    
*CFOPEN, eval_t5_tp1203840f_3e93_4bcb_b941_5e719cc9abd0_results, txt
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
