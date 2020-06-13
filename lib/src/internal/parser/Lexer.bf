using System;
using System.Collections;
using System.Text;
using System.Diagnostics;
using JetFistGames.Toml;

namespace JetFistGames.Toml.Internal
{
	class Lexer
	{
		typealias failable<T> = Result<T, TomlError>;
		typealias deferFunc = delegate failable<void>();

		private String _input;
		private int _start;
		private int _pos;
		private int _line;
		private int[5] _prevWidths;
		private int _nPrev;
		private List<Token> _tokens = new List<Token>() ~ delete _;
		private bool _atEOF;

		private List<deferFunc> _stack = new List<deferFunc>() ~ DeleteContainerAndItems!(_stack);

		public this(String input)
		{
			_input = input;
			_start = 0;
			_pos = 0;
			_line = 0;
			_atEOF = false;
		}

		public Result<List<Token>, TomlError> Lex()
		{
			Utils.Check!(LexTop());
			return .Ok(_tokens);
		}

		private mixin Fail(String fmt)
		{
			return .Err(TomlError(_line, fmt));
		}

		private void Push(deferFunc func)
		{
			_stack.Add(func);
		}

		private failable<void> Pop()
		{
			Debug.Assert(_stack.Count > 0, "Tried to pop empty stack");

			let func = _stack[_stack.Count - 1];
			_stack.RemoveAt(_stack.Count - 1);

			let result = func();
			delete func;

			return result;
		}

		private failable<char32> Next()
		{
			if (_atEOF)
			{
				Fail!("Unexpected EOF");
			}

			if (_pos >= _input.Length)
			{
				_atEOF = true;
				return '\0';
			}

			if (_input[_pos] == '\n')
			{
				_line++;
			}

			_prevWidths[4] = _prevWidths[3];
			_prevWidths[3] = _prevWidths[2];
			_prevWidths[2] = _prevWidths[1];
			_prevWidths[1] = _prevWidths[0];

			if (_nPrev < _prevWidths.Count)
				_nPrev++;

			let (char, len) = UTF8.Decode(&_input[_pos], _input.Length - _pos);
			_prevWidths[0] = len;
			_pos += len;
			return char;
		}

		private char32 Peek()
		{
			let r = Next();
			Backup();
			return r;
		}

		private void Emit(TokenType tokenType)
		{
			StringView value = StringView(_input, _start, _pos - _start);
			_tokens.Add(Token(tokenType, _line, value));
			_start = _pos;
		}

		private void Ignore()
		{
			_start = _pos;
		}

		private failable<void> Skip(delegate bool(char32) pred)
		{
			for (;;)
			{
				let r = Next();
				Utils.Check!(r);

				if (pred(r)) continue;

				Backup();
				Ignore();
				return .Ok;
			}
		}

		private void Backup()
		{
			if (_atEOF)
			{
				_atEOF = false;
				return;
			}

			if (_nPrev < 1)
			{
				Debug.FatalError("Exhausted backup buffer!");
			}

			let w = _prevWidths[0];

			_prevWidths[0] = _prevWidths[1];
			_prevWidths[1] = _prevWidths[2];
			_prevWidths[2] = _prevWidths[3];
			_prevWidths[3] = _prevWidths[4];

			_nPrev--;
			_pos -= w;

			if (_pos < _input.Length && _input[_pos] == '\n')
			{
				_line--;
			}
		}

		private failable<bool> Accept(char32 valid)
		{
			let r = Utils.Check!(Next());

			if (r == valid)
				return true;

			Backup();
			return false;
		}

		private failable<void> LexCommentStart()
		{
			Ignore();
			Emit(TokenType.CommentStart);
			return LexComment();
		}

		private failable<void> LexComment()
		{
			let r = Peek();
			if (IsNL(r) || r == '\0')
			{
				Emit(TokenType.Text);
				return Pop();
			}

			Utils.Check!(Next());
			return LexComment();
		}

		private failable<void> LexTableStart()
		{
			if (Peek() == '[')
			{
				Utils.Check!(Next());
				Emit(TokenType.ArrayTableStart);
				Push(new => LexArrayTableEnd);
			}
			else
			{
				Emit(TokenType.TableStart);
				Push(new => LexTableEnd);
			}

			return LexTableNameStart();
		}

		private failable<void> LexTableEnd()
		{
			Emit(TokenType.TableEnd);
			return LexTopEnd();
		}

		private failable<void> LexArrayTableEnd()
		{
			let r = Utils.Check!(Next());

			if (r != (.)']')
			{
				return .Err(TomlError(_line, "Expected end of table array name delimiter ']', but got {0} instead", r.Value));
			}

			Emit(TokenType.ArrayTableEnd);
			return LexTopEnd();
		}

		private failable<void> LexTableNameStart()
		{
			Utils.Check!(Skip(scope => IsWhitespace));

			let r = Peek();
			if (r == ']' || r == '\0')
			{
				Fail!("Unexpected end of table name (table names cannot be empty)");
			}
			else if (r == '.')
			{
				Fail!("Unexpected table separator (table names cannot start with '.')");
			}
			else if (r == '"' || r == '\'')
			{
				Ignore();
				Push(new => LexTableNameEnd);
				return LexValue();
			}

			return LexBareTableName();
		}

		private failable<void> LexBareTableName()
		{
			let r = Next();
			Utils.Check!(r);

			if(r == (.)'.')
			{
				Backup();
				Emit(TokenType.Text);
				Utils.Check!(Next());
				return LexTableNameStart();
			}
			else if (IsBareKeyChar(r))
			{
				return LexBareTableName();
			}
			else if(IsWhitespace(r))
			{
				Backup();
				Emit(.Text);
				return LexTableNameEnd();
			}

			Backup();
			Emit(TokenType.Text);
			return LexTableNameEnd();
		}

		private failable<void> LexTableNameEnd()
		{
			Utils.Check!(Skip(scope => IsWhitespace));

			let r = Utils.Check!(Next());

			if (IsWhitespace(r))
			{
				return LexTableNameEnd();
			}
			else if(r == (.)'.')
			{
				Utils.Check!(LexSkip());
				return LexTableNameStart();
			}
			else if (r == (.)']')
			{
				return Pop();
			}

			return .Err(TomlError(_line, "Expected ']' to end table name, but got {0} instead", r.Value));
		}

		private failable<void> LexKeyStart()
		{
			let r = Peek();
			if (r == (.)'=')
			{
				Fail!("Unexpected key separator '='");
			}
			else if (IsWhitespace(r) || IsNL(r))
			{
				Utils.Check!(Next());
				Utils.Check!(LexSkip());
				return LexKeyStart();
			}
			else if (r == (.)'"' || r == (.)'\'')
			{
				Ignore();
				Emit(TokenType.KeyStart);
				Push(new => LexKeyEnd);
				return LexValue();
			}

			Ignore();
			Emit(TokenType.KeyStart);
			return LexBareKey();
		}

		private failable<void> LexKeyEnd()
		{
			let r = Utils.Check!(Next());

			if (r == (.)'=')
			{
				Utils.Check!(LexSkip());
				return LexValue();
			}
			else if(r == (.)'.')
			{
				Utils.Check!(LexSkip());
				return LexKeyStart();
			}
			else if (IsWhitespace(r))
			{
				Utils.Check!(LexSkip());
				return LexKeyEnd();
			}

			return .Err(TomlError(_line, "Expected key separator '=' but got {0} instead", r.Value));
		}

		private failable<void> LexBareKey()
		{
			let r = Utils.Check!(Next());

			if( r == (.)'.' )
			{
				Backup();
				Emit(TokenType.Text);
				Utils.Check!(Next());
				return LexKeyStart();
			}
			else if (IsBareKeyChar(r))
			{
				return LexBareKey();
			}
			else if (IsWhitespace(r))
			{
				Backup();
				Emit(TokenType.Text);
				return LexKeyEnd();
			}
			else if (r == (.)'=')
			{
				Backup();
				Emit(TokenType.Text);
				return LexKeyEnd();
			}

			return .Err(TomlError(_line, "Bare keys cannot contain {0}", r.Value));
		}

		private failable<void> LexValue()
		{
			let r = Utils.Check!(Next());

			if (IsWhitespace(r))
			{
				Utils.Check!(LexSkip());
				return LexValue();
			}
			else if (r.Value.IsNumber)
			{
				Backup();
				return LexNumberOrDateStart();
			}
			else if (r == (.)'[')
			{
				Ignore();
				Emit(TokenType.Array);
				return LexArrayValue();
			}
			else if (r == (.)'{')
			{
				Ignore();
				Emit(TokenType.InlineTableStart);
				return LexInlineTableValue();
			}
			else if (r == (.)'"')
			{
				if (Utils.Check!(Accept('"')))
				{
					if (Utils.Check!(Accept('"')))
					{
						Ignore();
						return LexMultilineString();
					}
					Backup();
				}
				Ignore();
				return LexString();
			}
			else if (r == (.)'\'')
			{
				if (Utils.Check!(Accept('\'')))
				{
					if (Utils.Check!(Accept('\'')))
					{
						Ignore();
						return LexMultilineRawString();
					}
					Backup();
				}
				Ignore();
				return LexRawString();
			}
			else if (r == (.)'+' || r == (.)'-')
			{
				return LexNumberStart();
			}
			else if (r == (.)'.')
			{
				Fail!("Unexpected '.' character");
			}

			if (r.Value.IsLetter)
			{
				Backup();
				return LexBool();
			}

			return .Err(TomlError(_line, "Unexpected character: {0}", r.Value));
		}

		private failable<void> LexArrayValue()
		{
			let r = Utils.Check!(Next());

			if (IsWhitespace(r) || IsNL(r))
			{
				Utils.Check!(LexSkip());
				return LexArrayValue();
			}
			else if (r == (.)'#')
			{
				Push(new => LexArrayValue);
				return LexCommentStart();
			}
			else if (r == (.)',')
			{
				Fail!("Unexpected comma");
			}
			else if (r == (.)']')
			{
				return LexArrayEnd();
			}

			Backup();
			Push(new => LexArrayValueEnd);
			return LexValue();
		}

		private failable<void> LexArrayValueEnd()
		{
			let r = Utils.Check!(Next());

			if (IsWhitespace(r) || IsNL(r))
			{
				Utils.Check!(LexSkip());
				return LexArrayValueEnd();
			}
			else if (r == (.)'#')
			{
				Push(new => LexArrayValueEnd);
				return LexCommentStart();
			}
			else if (r == (.)',')
			{
				Ignore();
				return LexArrayValue();
			}
			else if (r == (.)']')
			{
				return LexArrayEnd();
			}

			return .Err(TomlError(_line, "Expected a comma or array terminator ], but got {0} instead", r.Value));
		}

		private failable<void> LexArrayEnd()
		{
			Ignore();
			Emit(TokenType.ArrayEnd);
			return Pop();
		}

		private failable<void> LexInlineTableValue()
		{
			let r = Utils.Check!(Next());

			if (IsWhitespace(r))
			{
				Utils.Check!(LexSkip());
				return LexInlineTableValue();
			}
			else if (IsNL(r))
			{
				Fail!("Unexpected newline");
			}
			else if (r == (.)'#')
			{
				Push(new => LexInlineTableValue);
				return LexCommentStart();
			}
			else if (r == (.)',')
			{
				Fail!("Unexpected comma");
			}
			else if (r == (.)'}')
			{
				return LexInlineTableEnd();
			}

			Backup();
			Push(new => LexInlineTableValueEnd);
			return LexKeyStart();
		}

		private failable<void> LexInlineTableValueEnd()
		{
			let r = Utils.Check!(Next());

			if (IsWhitespace(r))
			{
				Utils.Check!(LexSkip());
				return LexInlineTableValueEnd();
			}
			else if (IsNL(r))
			{
				Fail!("Unexpected newline");
			}
			else if (r == (.)'#')
			{
				Push(new => LexInlineTableValueEnd);
				return LexCommentStart();
			}
			else if (r == (.)',')
			{
				Ignore();
				return LexInlineTableValue();
			}
			else if (r == (.)'}')
			{
				return LexInlineTableEnd();
			}

			return .Err(TomlError(_line, "Expected a comma or inline table terminator }, but got {0} instead", r.Value));
		}

		private failable<void> LexInlineTableEnd()
		{
			Ignore();
			Emit(TokenType.InlineTableEnd);
			return Pop();
		}

		private failable<void> LexString()
		{
			let r = Utils.Check!(Next());

			if (r == (.)'\0')
			{
				Fail!("Unexpected EOF");
			}
			else if (IsNL(r))
			{
				Fail!("Unexpected newline");
			}
			else if (r == (.)'\\')
			{
				Push(new => LexString);
				return LexStringEscape();
			}
			else if (r == (.)'"')
			{
				Backup();
				Emit(TokenType.String);
				Utils.Check!(Next());
				Ignore();
				return Pop();
			}

			return LexString();
		}

		private failable<void> LexMultilineString()
		{
			let r = Utils.Check!(Next());

			if (r == (.)'\0')
			{
				Fail!("Unexpected EOF");
			}
			else if (r == (.)'\\')
			{
				return LexMultilineStringEscape();
			}
			else if (r == (.)'"')
			{
				if (Utils.Check!(Accept('"')))
				{
					if (Utils.Check!(Accept('"')))
					{
						// why are "ending a multiline string with four or five quotation marks" considered valid scenarios
						// that's stupid and it sucks and I hate it and it's stupid.

						if(Utils.Check!(Accept('"'))) Utils.Check!(Accept('"'));

						Backup();
						Backup();
						Backup();

						Emit(TokenType.MultilineString);

						Utils.Check!(Next());
						Utils.Check!(Next());
						Utils.Check!(Next());

						Ignore();

						return Pop();
					}

					Backup();
				}
			}

			return LexMultilineString();
		}

		private failable<void> LexRawString()
		{
			let r = Utils.Check!(Next());

			if (r == (.)'\0')
			{
				Fail!("Unexpected EOF");
			}
			else if (IsNL(r))
			{
				Fail!("Unexpected newline");
			}
			else if (r == (.)'\'')
			{
				Backup();
				Emit(TokenType.RawString);
				Utils.Check!(Next());
				Ignore();
				return Pop();
			}

			return LexRawString();
		}

		private failable<void> LexMultilineRawString()
		{
			let r = Utils.Check!(Next());

			if (r == (.)'\0')
			{
				Fail!("Unexpected EOF");
			}
			else if (r == (.)'\'')
			{
				if (Utils.Check!(Accept('\'')))
				{
					if (Utils.Check!(Accept('\'')))
					{
						if(Utils.Check!(Accept('\''))) Utils.Check!(Accept('\''));

						Backup();
						Backup();
						Backup();

						Emit(TokenType.RawMultilineString);

						Utils.Check!(Next());
						Utils.Check!(Next());
						Utils.Check!(Next());

						Ignore();

						return Pop();
					}

					Backup();
				}
			}

			return LexMultilineRawString();
		}

		private failable<void> LexMultilineStringEscape()
		{
			if (IsNL(Utils.Check!(Next())))
			{
				return LexMultilineString();
			}

			Backup();
			Push(new => LexMultilineString);
			return LexStringEscape();
		}

		private failable<void> LexStringEscape()
		{
			let r = Utils.Check!(Next());

			switch (r.Value)
			{
			case 'b': fallthrough;
			case 't': fallthrough;
			case 'n': fallthrough;
			case 'f': fallthrough;
			case 'r': fallthrough;
			case '"': fallthrough;
			case '\\': return Pop();
			case 'u':
				return LexShortUnicodeEscape();
			case 'U':
				return LexLongUnicodeEscape();
			default:
				return .Err(TomlError(_line, "Invalid escape character {0}, only the following escape characters are allowed: \\b, \\t, \\n, \\f, \\r, \\\", \\\\, \\uXXXX, and \\UXXXXXXXX", r.Value));
			}
		}

		private failable<void> LexShortUnicodeEscape()
		{
			char32 r;
			for (int i = 0; i < 4; i++)
			{
				r = Utils.Check!(Next());
				if (!IsHex(r))
					return .Err(TomlError(_line, "Expected four hexadecimal digits after \\u, but got {0} instead", r));
			}

			return Pop();
		}

		private failable<void> LexLongUnicodeEscape()
		{
			char32 r;
			for (int i = 0; i < 8; i++)
			{
				r = Utils.Check!(Next());
				if (!IsHex(r))
					return .Err(TomlError(_line, "Expected eight hexadecimal digits after \\U, but got {0} instead", r));
			}

			return Pop();
		}

		private failable<void> LexNumberOrDateStart()
		{
			let r = Utils.Check!(Next());

			// numbers starting with 0x, 0o, or 0b are actually hex, octal, or binary (respectively)
			// note: these are not allowed to have preceding - or + according to the spec
			if( r == (.)'0' )
			{
				if(Utils.Check!(Accept('x')))
				{
					return LexHex();
				}
				else if(Utils.Check!(Accept('o')))
				{
					return LexOct();
				}
				else if(Utils.Check!(Accept('b')))
				{
					return LexBin();
				}
			}

			if (r.Value.IsNumber)
			{
				return LexNumberOrDate();
			}
			else if (r == (.)'_')
			{
				return LexNumber();
			}
			else if (r == (.)'e' || r == (.)'E')
			{
				return LexFloat();
			}
			else if (r == (.)'.')
			{
				Fail!("Unexpected '.'");
			}

			return .Err(TomlError(_line, "Expected a digit but got {0}", r.Value));
		}

		private failable<void> LexNumberOrDate()
		{
			let r = Utils.Check!(Next());

			if (r.Value.IsNumber)
			{
				return LexNumberOrDate();
			}
			else if (r == (.)'-' || r == (.)':')
			{
				return LexDatetime();
			}
			else if (r == (.)'_')
			{
				return LexNumber();
			}
			else if (r == (.)'.' || r == (.)'e' || r == (.)'E')
			{
				return LexFloat();
			}

			Backup();
			Emit(TokenType.Integer);
			return Pop();
		}

		private failable<void> LexDatetime()
		{
			let r = Utils.Check!(Next());

			if (r.Value.IsNumber)
			{
				return LexDatetime();
			}
			else if (r.Value == '-' || r.Value == 'T' || r.Value == ':' || r.Value == '.' || r.Value == 'Z' || r.Value == '+' || r.Value == ' ')
			{
				return LexDatetime();
			}

			Backup();
			Emit(TokenType.Datetime);
			return Pop();
		}

		private failable<void> LexNumberStart()
		{
			let r = Utils.Check!(Next());

			if (!r.Value.IsNumber)
			{
				if (r == (.)'.')
				{
					Fail!("Unexpected '.'");
				}

				// inf?
				if(r == (.)'i')
				{
					if( Utils.Check!(Accept('n')))
					{
						if(Utils.Check!(Accept('f')))
						{
							Emit(TokenType.Float);
							return Pop();
						}

						Backup();
					}
				}

				// nan?
				if(r == (.)'n')
				{
					if( Utils.Check!(Accept('a')))
					{
						if(Utils.Check!(Accept('n')))
						{
							Emit(TokenType.Float);
							return Pop();
						}

						Backup();
					}
				}

				return .Err(TomlError(_line, "Expected digit but got {0}", r.Value));
			}

			return LexNumber();
		}

		private failable<void> LexHex()
		{
			let r = Utils.Check!(Next());

			if (IsHex(r))
			{
				return LexHex();
			}

			if (r == (.)'_')
			{
				return LexHex();
			}

			Backup();
			Emit(TokenType.Integer);
			return Pop();
		}

		private failable<void> LexOct()
		{
			let r = Utils.Check!(Next());

			if (IsOct(r))
			{
				return LexOct();
			}

			if (r == (.)'_')
			{
				return LexOct();
			}

			Backup();
			Emit(TokenType.Integer);
			return Pop();
		}

		private failable<void> LexBin()
		{
			let r = Utils.Check!(Next());

			if (IsBinary(r))
			{
				return LexBin();
			}

			if (r == (.)'_')
			{
				return LexBin();
			}

			Backup();
			Emit(TokenType.Integer);
			return Pop();
		}

		private failable<void> LexNumber()
		{
			let r = Utils.Check!(Next());

			if (r.Value.IsNumber)
			{
				return LexNumber();
			}

			if (r == (.)'_')
			{
				return LexNumber();
			}

			if (r == (.)'.' || r == (.)'e' || r == (.)'E')
			{
				return LexFloat();
			}

			Backup();
			Emit(TokenType.Integer);
			return Pop();
		}

		private failable<void> LexFloat()
		{
			let r = Utils.Check!(Next());

			if (r.Value.IsNumber)
			{
				return LexFloat();
			}

			if (r.Value == '_' || r.Value == '.' || r.Value == '-' || r.Value == '+' || r.Value == 'e' || r.Value == 'E')
			{
				return LexFloat();
			}

			Backup();
			Emit(TokenType.Float);
			return Pop();
		}

		private failable<void> LexBool()
		{
			let s = scope String();

			for (;;)
			{
				let r = Utils.Check!(Next());
				if (!r.Value.IsLetter)
				{
					Backup();
					break;
				}

				s.Append(r.Value);
			}

			if (s == "true" || s == "false")
			{
				Emit(TokenType.Bool);
				return Pop();
			}

			// awful workaround. or maybe I should just rename LexBool?
			if(s == "inf" || s == "nan")
			{
				Emit(TokenType.Float);
				return Pop();
			}

			return .Err(TomlError(_line, "Expected value but found {0} instead", s));
		}

		private failable<void> LexSkip()
		{
			Ignore();
			return .Ok;
		}

		private failable<void> LexTop()
		{
			let r = Utils.Check!(Next());

			if (IsWhitespace(r) || IsNL(r))
			{
				Ignore();
				return LexTop();
			}

			switch (r.Value)
			{
			case '#':
				Push(new => LexTop);
				return LexCommentStart();
			case '[':
				return LexTableStart();
			case '\0':
				if (_pos > _start)
					Fail!("Unexpected EOF");

				Emit(TokenType.EOF);
				return .Ok;
			}

			Backup();
			Push(new => LexTopEnd);
			return LexKeyStart();
		}

		private failable<void> LexTopEnd()
		{
			let r = Utils.Check!(Next());

			if (r == (.)'#')
			{
				Push(new => LexTopEnd);
				return LexCommentStart();
			}
			else if (IsWhitespace(r))
			{
				return LexTopEnd();
			}
			else if (IsNL(r))
			{
				Ignore();
				return LexTop();
			}
			else if (r == (.)'\0')
			{
				Emit(TokenType.EOF);
				return .Ok;
			}

			return .Err(TomlError(_line, "Expected a top level item to end with a newline, comment, or EOF but got {0} instead", r.Value));
		}

		private static bool IsHex(char32 r)
		{
			return (r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F');
		}

		private static bool IsOct(char32 r)
		{
			return (r >= '0' && r <= '7');
		}

		private static bool IsBinary(char32 r)
		{
			return r == '0' || r == '1';
		}

		private static bool IsBareKeyChar(char32 r)
		{
			return r.IsLetterOrDigit || r == '_' || r == '-' || r == '.';
		}

		private static bool IsWhitespace(char32 r)
		{
			return r == ' ' || r == '\t';
		}

		private static bool IsNL(char32 r)
		{
			return r == '\n' || r == '\r';
		}
	}
}
