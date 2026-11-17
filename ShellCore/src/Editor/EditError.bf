namespace Shell.Editor;

using System;

// Result of an editing operation that was refused (nothing changed).
enum EditError
{
	case None;
	case NotFound;          // an id does not exist
	case Essential;         // the operation would remove or break something the widget's behavior depends on
	case Cycle;             // would make an object its own ancestor
	case InvalidTarget;     // wrong kind of object, or the destination does not accept it
	case RoleOrder;         // would put Underlay / Overlay on the wrong side of Content
	case Duplicate;         // name or id already used
	case Blocked;           // references that cannot be rewritten (see the report)
}
