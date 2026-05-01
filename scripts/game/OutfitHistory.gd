class_name OutfitHistory
extends RefCounted

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func remember(snapshot: Dictionary) -> void:
	_undo_stack.append(snapshot.duplicate(true))
	_redo_stack.clear()


func undo(current_snapshot: Dictionary) -> Dictionary:
	if _undo_stack.is_empty():
		return {}
	_redo_stack.append(current_snapshot.duplicate(true))
	return _undo_stack.pop_back()


func redo(current_snapshot: Dictionary) -> Dictionary:
	if _redo_stack.is_empty():
		return {}
	_undo_stack.append(current_snapshot.duplicate(true))
	return _redo_stack.pop_back()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()
