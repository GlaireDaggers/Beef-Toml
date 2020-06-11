using System;
using System.Collections;
using System.Diagnostics;
using JetFistGames.Toml;

namespace JetFistGames.Toml.Internal
{
	public class Parser
	{
		private Lexer _lexer;
		private List<Token> _tokens;

		private TomlTableNode _root;
		private List<TomlTableNode> _nodeStack = new List<TomlTableNode>() ~ delete _;

		private TomlTableNode _activeNode => _nodeStack[_nodeStack.Count - 1];

		public this(String input)
		{
			_lexer = new Lexer(input);
		}

		public ~this()
		{
			delete _lexer;
		}

		public Result<T> Deserialize<T>(T dest) where T : new, class
		{
			let doc = Parse();
			if( doc case .Err(let err) )
			{
				return .Err;
			}

			let result = Deserialize(doc.Value, dest);
			delete doc.Value;

			if(result case .Err)
				return .Err;

			return dest;
		}

		public Result<T> Deserialize<T>() where T : new, struct
		{
			let doc = Parse();
			if( doc case .Err(let err) )
			{
				return .Err;
			}

			let dest = scope box T();
			let result = Deserialize(doc.Value, dest);
			delete doc.Value;

			if(result case .Err)
				return .Err;

			return dest;
		}

		private Result<void> Deserialize(TomlNode src, System.Object dest, Type t = null)
		{
			Type type = t;
			if(type == null)
				type = dest.GetType();

			let fields = type.GetFields();

			for(let field in fields)
			{
				// atomic type?
				if(field.FieldType.IsInteger)
				{
					let val = src[scope String(field.Name)].GetInt();
					if( val case .Err )
						return .Err;

					field.SetValue(dest, val.Value);
				}
				else if(field.FieldType == typeof(float))
				{
					let val = src[scope String(field.Name)].GetFloat();
					if( val case .Err )
						return .Err;

					field.SetValue(dest, (float)val.Value);
				}
				else if(field.FieldType == typeof(double))
				{
					let val = src[scope String(field.Name)].GetFloat();
					if( val case .Err )
						return .Err;

					field.SetValue(dest, val.Value);
				}
				else if(field.FieldType == typeof(bool))
				{
					let val = src[scope String(field.Name)].GetBool();
					if( val case .Err )
						return .Err;

					field.SetValue(dest, val.Value);
				}
				else if(field.FieldType == typeof(DateTime))
				{
					let val = src[scope String(field.Name)].GetDatetime();
					if( val case .Err )
						return .Err;

					field.SetValue(dest, val.Value);
				}
				else if(field.FieldType == typeof(String))
				{
					let val = src[scope String(field.Name)].GetString();
					if( val case .Err )
						return .Err;

					String s = new String();
					s.Set(val.Value);

					// field.SetValue(dest, s);

					// WORKAROUND: As of 0.42.3, FieldInfo.SetValue doesn't work for object references (such as String)
					// so instead I manually construct a pointer to the field to assign the reference

					var fieldPtr = (String*)(((uint8*)(void*)dest) + field.MemberOffset);
					*fieldPtr = s;
				}
				else if(field.FieldType.IsStruct)
				{
					var fieldVal = field.GetValue(dest);
					if( fieldVal case .Err)
						return .Err;

					let val = src[scope String(field.Name)].GetTable();
					if( val case .Err )
						return .Err;

					let tmp = new box fieldVal.Value;

					Deserialize(val.Value, tmp, field.FieldType);

					var fieldPtr = (String*)(((uint8*)(void*)dest) + field.MemberOffset);
					tmp.CopyValueData(fieldPtr);

					delete tmp;
				}
				else
				{
					return .Err;
				}
			}

			return .Ok;
		}

		public Result<TomlNode, TomlError> Parse()
		{
			let lexResult = _lexer.Lex();

			if (lexResult case .Err(let err))
			{
				return .Err(err);
			}

			_tokens = lexResult.Value;
			_root = new TomlTableNode();

			Push(_root);

			if( ParseTop() case .Err(let err) )
				return .Err(err);

			return _root;
		}

		private void Replace(TomlTableNode node)
		{
			Pop();
			Push(node);
		}

		private void Push(TomlTableNode node)
		{
			_nodeStack.Add(node);
		}

		private void Pop()
		{
			_nodeStack.RemoveAt(_nodeStack.Count - 1);
		}

		private T Find<T>(StringView path) where T : TomlNode
		{
			return _root.Find<T>(path);
		}

		private Result<void, String> Insert(TomlTableNode start, StringView path, TomlNode value)
		{
			TomlTableNode curNode = start;

			var next = curNode.FindChild(path);
			if (next == null)
			{
				return curNode.AddChild(path, value);
			}
			else
			{
				return .Err("Value already defined at key path");
			}
		}

		private Result<T, String> GetOrCreate<T>(TomlTableNode start, StringView path, bool ignoreDup = true) where T : TomlNode
		{
			TomlTableNode curNode = start;

			var sep = path.Split('.');
			for (var child in sep)
			{
				var next = curNode.FindChild(child);
				if (next == null)
				{
					if (sep.HasMore)
					{
						curNode = curNode.AddChild<TomlTableNode>(child);
					}
					else
					{
						return curNode.AddChild<T>(child);
					}
				}
				else
				{
					if (ignoreDup)
					{
						if (sep.HasMore)
						{
							curNode = next as TomlTableNode;
							if (curNode == null)
								return .Err("Value at key path already defined as another type");
						}
						else
						{
							if (!next is T)
							{
								return .Err("Value at key path already defined as another type");
							}

							return (T)next;
						}
					}
					else
					{
						return .Err("Value already defined at key path");
					}
				}
			}

			return .Err("");
		}

		private Token Next()
		{
			let token = _tokens[0];
			_tokens.RemoveAt(0);

			return token;
		}

		private Token Peek()
		{
			return _tokens[0];
		}

		private Result<Token, TomlError> Match(TokenType tokenType)
		{
			var nextToken = Peek();

			if (nextToken.Kind != tokenType)
				return .Err(TomlError(nextToken.Line, "Expected token {0} but found {1}", tokenType, nextToken.Kind));

			return Next();
		}

		private bool Check(TokenType tokenType)
		{
			return Peek().Kind == tokenType;
		}

		private Result<void, TomlError> ParseTop()
		{
			let token = Next();

			switch (token.Kind)
			{
			case .EOF:
				return .Ok;
			case .CommentStart:
				Utils.Check!(ParseComment());
				break;
			case .KeyStart:
				Utils.Check!(ParseKey());
				break;
			case .TableStart:
				Utils.Check!(ParseTable());
				break;
			case .ArrayTableStart:
				Utils.Check!(ParseArrayTable());
				break;
			default:
				return .Err(TomlError(token.Line, "Unexpected token: {0}", token.Value));
			}

			return ParseTop();
		}

		private Result<TomlNode, TomlError> ParseValueTop()
		{
			let token = Next();

			switch (token.Kind)
			{
			case .InlineTableStart:
				return ParseInlineTable();
			case .Array:
				return ParseArray();
			case .Bool:
				fallthrough;
			case .Datetime:
				fallthrough;
			case .Float:
				fallthrough;
			case .Integer:
				return new TomlValueNode(token.Kind, token.Value);
			case .String:
				fallthrough;
			case .MultilineString:
				fallthrough;
			case .RawString:
				fallthrough;
			case .RawMultilineString:
				return new TomlValueNode(TokenType.String, token.Value);
			default:
				return .Err(TomlError(token.Line, "Unexpected token: {0}", token.Value));
			}
		}

		private Result<TomlNode, TomlError> ParseInlineTable()
		{
			TomlTableNode containerNode = new TomlTableNode();
			Push(containerNode);
			{
				for (;;)
				{
					if (Check(.InlineTableEnd))
					{
						Next();
						break;
					}

					Utils.Check!(Match(.KeyStart));

					if (ParseKey() case .Err(let err))
					{
						delete containerNode;
						return .Err(err);
					}
				}
			}
			Pop();
			return .Ok(containerNode);
		}

		private Result<TomlNode, TomlError> ParseArray()
		{
			TomlArrayNode arrayNode = new TomlArrayNode();

			for (;;)
			{
				if (Check(.ArrayEnd))
				{
					Next();
					break;
				}

				let value = ParseValueTop();

				if (value case .Err(let err))
				{
					delete arrayNode;
					return .Err(err);
				}

				arrayNode.AddChild(value);
			}

			return .Ok(arrayNode);
		}

		/// Parse # comment
		private Result<void, TomlError> ParseComment()
		{
			if (Match(.Text) case .Err(let err))
				return .Err(err);

			return .Ok;
		}

		/// Parse key = value
		private Result<void, TomlError> ParseKey()
		{
			Token key;

			if( Check(.String) )
			{
				key = Next();
			}
			else
			{
				key = Utils.Check!(Match(TokenType.Text)).Value;
			}

			var value = Utils.Check!(ParseValueTop()).Value;

			var target = Insert(_activeNode, key.Value, value);

			if (target case .Err(let err))
			{
				delete value;
				return .Err(TomlError(key.Line, err));
			}

			return .Ok;
		}

		/// Parse [tableName]
		private Result<void, TomlError> ParseTable()
		{
			var key = Utils.Check!(Match(TokenType.Text)).Value;
			Utils.Check!(Match(.TableEnd));

			let node = GetOrCreate<TomlTableNode>(_root, key.Value);

			if (node case .Err(let err))
				return .Err(TomlError(key.Line, err));

			Replace(node);
			return .Ok;
		}

		/// Parse [[tableName]]
		private Result<void, TomlError> ParseArrayTable()
		{
			var key = Utils.Check!(Match(TokenType.Text)).Value;
			Utils.Check!(Match(.ArrayTableEnd));

			let targetArray = GetOrCreate<TomlArrayNode>(_root, key.Value);

			if (targetArray case .Err(let err))
				return .Err(TomlError(key.Line, err));

			Replace(targetArray.Value.AddChild<TomlTableNode>());
			return .Ok;
		}
	}
}
