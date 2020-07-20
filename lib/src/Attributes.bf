using System;

namespace JetFistGames.Toml
{
	[AttributeUsage(.Class, .ReflectAttribute, ReflectUser=.All)]
	public struct DataContractAttribute : Attribute
	{

	}

	[AttributeUsage(.Field | .Property, .ReflectAttribute)]
	public struct DataMemberAttribute : Attribute
	{
		public String Name;

		public this()
		{
			Name = "";
		}

		public this(String Name)
		{
			this.Name = Name;
		}
	}

	[AttributeUsage(.Field | .Property)]
	public struct NotDataMemberAttribute : Attribute
	{
		
	}
}
