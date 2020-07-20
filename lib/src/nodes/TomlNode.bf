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

		public abstract Object ToObject();
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

		public T Find<T>(StringView name) where T : TomlNode
		{
			TomlNode curNode = FindChild(name);
			if (curNode == null)
				return null;

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

		public override Object ToObject()
		{
			var dict = new Dictionary<String, Object>((int32) Children.Count);
			for (var key in Children.Keys)
				dict[new String(key)] = Children[key].ToObject();
			return dict;
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

		public override Object ToObject()
		{
			var list = new List<Object>(Children.Count);
			for (var child in Children)
				list.Add(child);
			return list;
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

		private int _intValue = 0;
		private double _floatValue = 0.0;
		private bool _boolValue = false;
		private DateTime _dtValue = DateTime.Now;
		private String _stringValue = new String("") ~ delete _;

		public this()
		{
			ValueType = .String;
		}

		public this(TokenType tokenType, StringView value)
		{
			ValueType = tokenType;

			if(tokenType == .Integer)
			{
				_intValue = Utils.ParseNumber(value).Value;
			}
			else if(tokenType == .Float)
			{
				_floatValue = Utils.ParseFloat(value).Value;
			}
			else if(tokenType == .String)
			{
				Utils.Unescape(value, _stringValue);
			}
			else if(tokenType == .RawString)
			{
				ValueType = .String;
				_stringValue.Set(value);
			}
			else if(tokenType == .MultilineString)
			{
				ValueType = .String;

				var v = value;
				if(v[0] == '\n') v = StringView(v, 1);

				Utils.UnescapeMultiline(v, _stringValue);
			}
			else if(tokenType == .RawMultilineString)
			{
				ValueType = .String;

				var v = value;
				if(v[0] == '\n') v = StringView(v, 1);

				_stringValue.Set(v);
			}
			else if(tokenType == .Bool)
			{
				_boolValue = value == "true" ? true : false;
			}
			else if(tokenType == .Datetime)
			{
				// bad workaround for lexer passing through whitespace at end of datetime token
				var v = value;
				v..TrimStart()..TrimEnd();

				_dtValue = DateParser.Parse(v);
			}
		}

		public override TomlNode FindChild(StringView name)
		{
			return null;
		}

		public void SetInt(int val)
		{
			ValueType = .Integer;
			_intValue = val;
		}

		public void SetFloat(double val)
		{
			ValueType = .Float;
			_floatValue = val;
		}

		public void SetBool(bool val)
		{
			ValueType = .Bool;
			_boolValue = val;
		}

		public void SetString(StringView val)
		{
			ValueType = .String;
			_stringValue.Set(val);
		}

		public void SetDatetime(DateTime val)
		{
			/*ValueType = .Integer;
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
			}*/

			ValueType = .Datetime;
			_dtValue = val;
		}

		public override Result<int> GetInt()
		{
			if(ValueType != .Integer) return .Err;
			return _intValue;
		}

		public override Result<double> GetFloat()
		{
			if(ValueType != .Float) return .Err;
			return _floatValue;
		}

		public override Result<bool> GetBool()
		{
			if(ValueType != .Bool) return .Err;
			return _boolValue;
		}

		public override Result<DateTime> GetDatetime()
		{
			if(ValueType != .Datetime) return .Err;
			return _dtValue;
		}

		public override Result<String> GetString()
		{
			if(ValueType != .String) return .Err;
			return _stringValue;
		}

		public override Object ToObject()
		{
			switch (ValueType)
			{
			case .String:
				return new String(_stringValue);
			case .Integer:
				return _intValue;
			case .Float:
				return _floatValue;
			case .Bool:
				return _boolValue;
			case .Datetime:
				return new box _dtValue;
			default:
				return null;
			}
		}
	}
}
