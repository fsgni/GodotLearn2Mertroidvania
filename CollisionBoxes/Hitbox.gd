extends Area2D

export var damage = 1


func _on_Hitbox_area_entered(hurtbox):
	hurtbox.emit_signal("hit", damage)
