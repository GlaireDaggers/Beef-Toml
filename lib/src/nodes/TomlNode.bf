using System;
using System.Collections;
using System.Diagnostics;

namespace JetFistGames.Toml
{
	using JetFistGames.Toml.Internal;

	public enum TomlValueType
	{
		Int,
		Float,
		Bool,
		String,
		Datetime,
		Table,
		Array
	}

	abstract class TomlNode
	{
		public abstract TomlValueType Kind { get; }
		public abstract TomlNode FindChild(StringView name);

		public virtual TomlNode this[String key]
		{
			get
			{
				return null;
			}
		}

		public virtual TomlNode this[int index] {
			get {
				return null;
			}
		}

		public virtual Result<int> GetInt()
		{
			return .Err;
		}

		public virtual Result<double> GetFloat()
		{
			return .Err;
		}

		public virtual Result<bool> GetBool()
		{
			return .Err;
		}

		public virtual Result<DateTime> GetDatetime()
		{
			return .Err;
		}

		public virtual Result<String> GetString()
		{
			return .Err;
		}

		public virtual Result<TomlTableNode> GetTable()
		{
			return .Err;
		}

		public virtual Result<TomlArrayNode> GetArray()
		{
			return .Err;
		}
	}

	public class TomlTableNode : TomlNode
	{
		public override TomlValueType Kind=> TomlValueType.Table;

		private Dictionary<String, TomlNode> Children = new Dictionary<String, TomlNode>() ~ DeleteDictionaryAndKeysAndItems!(Children);

		public Dictionary<String, TomlNode>.KeyEnumerator Keys => Children.Keys;

		public override TomlNode this[String key]
		{
			get {
				return Find<TomlNode>(key);
			}
		}

		public override TomlNode this[int index]
		{
			get {
				String tmp = scope String();
				index.ToString(tmp);
				return Find<TomlNode>(tmp);
			}
		}

		public override Result<TomlTableNode> GetTable()
		{
			return this;
		}

		public override TomlNode FindChild(StringView name)
		{
			String tmp = scope String(name);

			if (Children.ContainsKey(tmp))
				return Children[tmp];

			return null;
		}

		public T Find<T>(StringView path) where T : TomlNode
		{
			TomlNode curNode = this;

			var sep = path.Split('.');
			for (var child in sep)
			{
				curNode = curNode.FindChild(child);
				if (curNode == null)
					return null;
			}

			return (T)curNode;
		}

		public T AddChild<T>(StringView name) where T : TomlNode, new
		{
			let child = new T();

			Children.Add(new String(name), child);

			return child;
		}

		public void AddChild(StringView name, TomlNode child)
		{
			Children.Add(new String(name), child);
		}
	}

	public class TomlArrayNode : TomlNode
	{
		public override TomlValueType Kind=> TomlValueType.Array;

		public int Count => Children.Count;

		private List<TomlNode> Children = new List<TomlNode>() ~ DeleteContainerAndItems!(Children);

		public override TomlNode FindChild(StringView name)
		{
			return null;
		}

		public T AddChild<T>() where T : TomlNode, new
		{
			let child = new T();

			Children.Add(child);

			return child;
		}

		public void AddChild(TomlNode child)
		{
			Children.Add(child);
		}

		public override Result<TomlArrayNode> GetArray()
		{
			return this;
		}

		public override TomlNode this[int index]
		{
			get
			{
				return Children[index];
			}
		}

		public override TomlNode this[String key]
		{
			get
			{
				if(int.Parse(key) case .Ok(let idx))
				{
					return Children[idx];
				}

				return null;
			}
		}
	}

	public class TomlValueNode : TomlNode
	{
		public override TomlValueType Kind
		{
			get
			{
				switch (ValueType)
				{
				case .Integer:
					return .Int;
				case .Float:
					return .Float;
				case .Bool:
					return .Bool;
				case .String:
					fallthrough;
				case .RawString:
					fallthrough;
				case .MultilineString:
					fallthrough;
				case .RawMultilineString:
					return .String;
				case .Datetime:
					return .Datetime;
				default:
					Debug.FatalError("Invalid token type assigned to value node! Something has gone wrong");
				}

				return .String;
			}
		}

		private TokenType ValueType;
		private String Value = new String() ~ delete _;

		public this()
		{
			ValueType = .String;
			Value.Set("");
		}

		public this(TokenType tokenType, StringView value)
		{
			ValueType = tokenType;
			Value.Set(value);

			// bad workaround for lexer passing through whitespace at end of datetime token
			if(tokenType == .Datetime)
			{
				Value.TrimStart();
				Value.TrimEnd();
			}
		}

		public override TomlNode FindChild(StringView name)
		{
			return null;
		}

		public override Result<int> GetInt()
		{
			let val = int.Parse(Value);
			if (val case .Err)
				return .Err;

			return val.Value;
		}

		public void SetInt(int val)
		{
			ValueType = .Integer;
			Value.Clear();
			val.ToString(Value);
		}

		public void SetFloat(float val)
		{
			ValueType = .Integer;
			Value.Clear();
			val.ToString(Value);
		}

		public void SetBool(bool val)
		{
			ValueType = .Integer;
			Value.Clear();
			val.ToString(Value);
		}

		public void SetString(StringView val)
		{
			ValueType = .String;
			Value.Set(val);
		}

		public void SetDatetime(DateTime val)
		{
			ValueType = .Integer;
			Value.Clear();
			val.ToString(Value, "yyyy-MM-dd HH:mm:ss.FFF");

			switch(val.Kind)
			{
			case .Utc:
				Value.Append("Z");
				break;
			case .Local:
				// get local offset from UTC
				let offset = TimeZoneInfo.Local.GetUtcOffset(val);
				float min = offset.Minutes;
				min += (offset.Seconds / 60f);
				min += (offset.Milliseconds / 1000f);
				Value.AppendF("{0:02}:{1:00.#}", offset.Hours, min);
				break;
			case .Unspecified:
				break;
			}
		}

		public override Result<double> GetFloat()
		{
			let val = double.Parse(Value);
			if (val case .Err)
				return .Err;

			return val.Value;
		}

		public override Result<bool> GetBool()
		{
			if (Value == "true")
				return true;
			else if (Value == "false")
				return false;

			return .Err;
		}

		public override Result<DateTime> GetDatetime()
		{
			return DateParser.Parse(Value);
		}

		public override Result<String> GetString()
		{
			return Value;
		}
	}
}
