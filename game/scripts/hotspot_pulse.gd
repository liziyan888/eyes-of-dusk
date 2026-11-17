extends RefCounted
## Radius breathes independently of hover; only the extra light follows input.
static func appearance(clock:float,highlight:float,radius:float,idle_alpha:=.60,hover_alpha:=.98,completed_scale:=1.0)->Vector3:
	var wave:=sin(clock*2.2)
	var breath:=wave*.5+.5
	var r:=radius*(1.0+wave*.06+highlight*.035)
	var alpha:=lerpf(idle_alpha+breath*.06,hover_alpha,highlight)*completed_scale
	var halo:=(.035+breath*.025+highlight*.08)*completed_scale
	return Vector3(r,alpha,halo)
