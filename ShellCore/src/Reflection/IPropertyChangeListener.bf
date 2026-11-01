namespace Shell.Reflection;

using System;
using Shell.Core;

interface IPropertyChangeListener
{
	void OnPropertyChanged(PropertyStore store, PropertyDescriptor property, Value oldValue, Value newValue);
}
