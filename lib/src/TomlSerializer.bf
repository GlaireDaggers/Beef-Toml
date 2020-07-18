using System;
using System.Collections;
using JetFistGames.Toml.Internal;

namespace JetFistGames.Toml
{
	public sealed class TomlSerializer
	{
		public static Result<TomlNode,TomlError> Read(StringView input)
		{
			let parser = new Parser(scope String(input));
			let result = parser.Parse();

			delete parser;

			switch(result)
			{
			case .Ok(let val):
				return .Ok(val);
			case .Err(let err):
				return .Err(err);
			}
		}

		public static Result<void, TomlError> Read<T>(StringView input, T dest) where T : class
		{
			let result = Read(input);

			if (result case .Err(let err))
				return .Err(err);

			let doc = (TomlTableNode) result.Get();
			var fields = dest.GetType().GetFields();

			bool isContract = typeof(T).GetCustomAttribute<DataContractAttribute>() case .Ok;

			for (let key in doc.Keys)
			{
				for (let field in fields)
				{
					StringView fieldName = field.Name;
					if (fieldName.StartsWith("prop__"))
						fieldName = StringView(field.Name, 6);

					if (isContract && field.GetCustomAttribute<DataMemberAttribute>() case .Ok(let val))
					{
						if (val.Name != "")
							fieldName = StringView(val.Name);
					}	
					else if (isContract || fieldName != key || field.GetCustomAttribute<NotDataMemberAttribute>() case .Ok)
						continue;

					if (IsMatchingType(doc[key].Kind, field.FieldType))
					{
						switch (doc[key].Kind)
						{
						case .String:
							field.SetValue(dest, new String(doc[key].GetString().Get()));
							break;
						case .Int:
							field.SetValue(dest, doc[key].GetInt().Get());
							break;
						case .Float:
							field.SetValue(dest, doc[key].GetFloat().Get());
							break;
						case .Bool:
							field.SetValue(dest, doc[key].GetBool().Get());
							break;
						case .Table:
							field.SetValue(dest, (Dictionary<String, Object>) doc[key].GetTable().Get().ToObject());
							break;
						case .Array:
							field.SetValue(dest, doc[key].GetString().Get());
							break;
						case .Datetime:
							field.SetValue(dest, doc[key].GetString().Get());
							break;
						}
					}
				}

				fields.Reset();
			}

			delete doc;

			return .Ok;
			
			bool IsMatchingType(TomlValueType valueType, Type fieldType)
			{
				if ((valueType == .String   && fieldType == typeof(String))                     ||
				    (valueType == .Int      && fieldType == typeof(int))                        ||
				    (valueType == .Float    && fieldType == typeof(float))                      ||
				    (valueType == .Bool     && fieldType == typeof(bool))                       ||
				    (valueType == .Table    && fieldType == typeof(Dictionary<String, Object>)) ||
				    (valueType == .Array    && fieldType == typeof(List<Object>))               ||
				    (valueType == .Datetime && fieldType == typeof(DateTime)))
						return true;

				return false;
			}
		}

		public static void Write(TomlTableNode root, String output)
		{
			output.Clear();

			let arrayKeys = scope List<StringView>();
			let tableKeys = scope List<StringView>();

			// first, we need to write any root-level atomic values, skipping arrays and tables
			for(var key in root.Keys)
			{
				var node = root[key];

				if(node.Kind == .Array)
				{
					arrayKeys.Add(key);
				}
				else if(node.Kind == .Table)
				{
					tableKeys.Add(key);
				}
				else
				{
					output.AppendF("{0} = ", key);
					Emit(node, output);
					output.Append("\n");
				}
			}

			output.Append("\n");

			// now let's write arrays
			for(var key in arrayKeys)
			{
				output.AppendF("{0} = ", key);
				EmitInlineArray(root[scope String(key)].GetArray(), output);
				output.Append("\n");
			}

			output.Append("\n");

			// and finally tables
			for(var key in tableKeys)
			{
				output.AppendF("[{0}]\n", key);
				EmitTableContents(root[scope String(key)].GetTable(), output);
				output.Append("\n");
			}
		}

		private static void EmitTableContents(TomlTableNode node, String output)
		{
			for(var key in node.Keys)
			{
				var val = node[key];

				output.AppendF("{0} = ", key);
				Emit(val, output);
				output.Append("\n");
			}
		}

		private static void Emit(TomlNode node, String output)
		{
			if(node.Kind == .Table)
			{
				EmitInlineTable(node.GetTable(), output);
			}
			else if(node.Kind == .Array)
			{
				EmitInlineArray(node.GetArray(), output);
			}
			else if(node.Kind == .String)
			{
				output.AppendF("\"{0}\"", node.GetString().Value);
			}
			else
			{
				output.Append(node.GetString().Value);
			}
		}

		private static void EmitInlineArray(TomlArrayNode node, String output)
		{
			output.Append("[ ");

			for(int i = 0; i < node.Count; i++)
			{
				Emit(node[i], output);
				if(i < node.Count - 1)
					output.Append(", ");
			}

			output.Append(" ]");
		}

		private static void EmitInlineTable(TomlTableNode node, String output)
		{
			output.Append("{ ");

			bool prev = false;
			for(var key in node.Keys)
			{
				if( prev )
					output.Append(", ");

				output.AppendF("{0} = ", key);
				Emit(node[key], output);

				prev = true;
			}

			output.Append(" }");
		}
	}
}
