namespace Shell.Blueprints;

using System;

enum BlueprintRefKind
{
	case Self;
	case OwnerWidget;       // Blueprint attached to the same Widget / UserWidget as the caller (by asset id)
	case Instance;          // a specific instance by StableId (e.g. exposed through a UserWidget)
	case Singleton;         // the one instance of a global/service Blueprint (by asset id); missing = diagnostic
}
