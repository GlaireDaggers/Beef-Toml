using System;

namespace JetFistGames.Toml.Internal
{
	class Utils
	{
		public static mixin Check<T>(Result<T> result)
		{
			if (result case .Err)
				return .Err();
		}

		public static mixin Check<T, TResult>(Result<T, TResult> result)
		{
			if (result case .Err(let err))
				return .Err(err);

			result
		}

		public static Result<void> Unescape(StringView src, String dest)
		{
			for (int i = 0; i < src.Length; i++)
			{
				let char = src[i];

				if (char == '\\')
				{
					i++;
					switch (src[i])
					{
					case 'b':
						dest.Append('\b');
						break;
					case 't':
						dest.Append('\t');
						break;
					case 'n':
						dest.Append('\n');
						break;
					case 'f':
						dest.Append('\f');
						break;
					case 'r':
						dest.Append('\r');
						break;
					case '"':
						dest.Append('"');
						break;
					case '\\':
						dest.Append('\\');
						break;
					case 'u':
						if (ParseShortUnicode(StringView(src, i + 1)) case .Ok(let val))
						{
							dest.Append(val);
							i += 4;
						}
						else
						{
							return .Err;
						}
						break;
					case 'U':
						if (ParseLongUnicode(StringView(src, i + 1)) case .Ok(let val))
						{
							dest.Append(val);
							i += 8;
						}
						else
						{
							return .Err;
						}
						break;
					default:
						return .Err;// invalid escape sequence
					}
				}
				else
				{
					dest.Append(char);
				}
			}

			return .Ok;
		}

		public static Result<void> UnescapeMultiline(StringView src, String dest)
		{
			for (int i = 0; i < src.Length; i++)
			{
				let char = src[i];

				if (char == '\\')
				{
					i++;
					switch (src[i])
					{
					case '\n':
						repeat
						{
							i++;
						} while (src[i].IsWhiteSpace);
						i--;
						break;
					case 'b':
						dest.Append('\b');
						break;
					case 't':
						dest.Append('\t');
						break;
					case 'n':
						dest.Append('\n');
						break;
					case 'f':
						dest.Append('\f');
						break;
					case 'r':
						dest.Append('\r');
						break;
					case '"':
						dest.Append('"');
						break;
					case '\\':
						dest.Append('\\');
						break;
					case 'u':
						if (ParseShortUnicode(StringView(src, i + 1)) case .Ok(let val))
						{
							dest.Append(val);
							i += 4;
						}
						else
						{
							return .Err;
						}
						break;
					case 'U':
						if (ParseLongUnicode(StringView(src, i + 1)) case .Ok(let val))
						{
							dest.Append(val);
							i += 8;
						}
						else
						{
							return .Err;
						}
						break;
					default:
						return .Err;// invalid escape sequence
					}
				}
				else
				{
					dest.Append(char);
				}
			}

			return .Ok;
		}

		public static Result<char32> ParseShortUnicode(StringView str)
		{
			if (str.Length < 4) return .Err;

			int mul = 1;
			int val = 0;
			for (int i = 3; i >= 0; i--)
			{
				if (!IsHex(str[i])) return .Err;

				let c = str[i].ToLower;

				if (c.IsDigit)
				{
					val += ((int)c - (int)'0') * mul;
				}
				else
				{
					val += (((int)c - (int)'a') + 10) * mul;
				}

				mul <<= 4;
			}

			return (char32)val;
		}

		public static Result<char32> ParseLongUnicode(StringView str)
		{
			if (str.Length < 8) return .Err;

			int mul = 1;
			int val = 0;
			for (int i = 7; i >= 0; i--)
			{
				if (!IsHex(str[i])) return .Err;

				let c = str[i].ToLower;

				if (c.IsDigit)
				{
					val += ((int)c - (int)'0') * mul;
				}
				else
				{
					val += (((int)c - (int)'a') + 10) * mul;
				}

				mul <<= 4;
			}

			return (char32)val;
		}

		public static Result<int> ParseHex(StringView str)
		{
			int mul = 1;
			int val = 0;

			for (int i = str.Length - 1; i >= 0; i--)
			{
				let c = str[i].ToLower;

				if(c == '_') continue;
				if (!IsHex(c)) return .Err;

				if (c.IsDigit)
				{
					val += ((int)c - (int)'0') * mul;
				}
				else
				{
					val += (((int)c - (int)'a') + 10) * mul;
				}

				mul <<= 4;
			}

			return val;
		}

		public static Result<int> ParseOctal(StringView str)
		{
			int mul = 1;
			int val = 0;

			for (int i = str.Length - 1; i >= 0; i--)
			{
				let c = str[i];

				if(c == '_') continue;
				if (!IsOct(c)) return .Err;

				val += ((int)c - (int)'0') * mul;

				mul <<= 3;
			}

			return val;
		}

		public static Result<int> ParseBinary(StringView str)
		{
			int mul = 1;
			int val = 0;

			for (int i = str.Length - 1; i >= 0; i--)
			{
				let c = str[i];

				if(c == '_') continue;
				if (!IsBin(c)) return .Err;

				val += ((int)c - (int)'0') * mul;

				mul <<= 1;
			}

			return val;
		}

		public static Result<int> ParseNumber(StringView str)
		{
			if (str.StartsWith("0x"))
			{
				return ParseHex(StringView(str, 2));
			}
			else if (str.StartsWith("0o"))
			{
				return ParseOctal(StringView(str, 2));
			}
			else if (str.StartsWith("0b"))
			{
				return ParseBinary(StringView(str, 2));
			}

			var curStr = str;
			int sign = 1;

			if (curStr[0] == '-')
			{
				sign = -1;
				curStr = StringView(curStr, 1);
			}
			else if(curStr[0] == '+')
			{
				curStr = StringView(curStr, 1);
			}

			int mul = 1;
			int val = 0;
			for(int i = curStr.Length - 1; i >= 0; i--)
			{
				let c = curStr[i];

				if(c == '_') continue;
				if (!c.IsDigit) return .Err;

				val += ((int)c - (int)'0') * mul;

				mul *= 10;
			}

			return val * sign;
		}

		public static Result<double> ParseFloat(StringView str)
		{
			if(str == "inf" || str == "+inf")
			{
				return double.PositiveInfinity;
			}
			else if(str == "-inf")
			{
				return double.NegativeInfinity;
			}
			else if(str == "nan" || str == "+nan" || str == "-nan")
			{
				return double.NaN;
			}

			int sc = 0, sl = str.Length;

			double curVal = 0;
			bool negative = false;

			if(str[sc] == '-')
			{
				negative = true;
				sc++;
			}
			else if(str[sc] == '+')
			{
				sc++;
			}

			if(str[sc] != '.')
			{
				while(sc < sl)
				{
					char8 ch = str[sc];

					if( ch == '_' )
					{
						sc++;
						continue;
					}

					if(ch == '.' || ch == 'e' || ch == 'E') break;
					else if(!ch.IsDigit) return .Err;

					int digit = (int)(ch - '0');
					curVal = ( curVal * 10 ) + digit;

					sc++;
				}
			}

			// fractional?
			if(sc < sl && str[sc] == '.')
			{
				sc++;

				int place = 10;

				while(sc < sl)
				{
					char8 ch = str[sc];

					if( ch == '_' )
					{
						sc++;
						continue;
					}

					if(ch == 'e' || ch == 'E') break;
					if(!ch.IsDigit) return .Err;

					int digit = (int)(ch - '0');
					curVal += (double)digit / place;

					place *= 10;

					sc++;
				}
			}

			// exponent?
			if(sc < sl && str[sc].ToLower == 'e')
			{
				sc++;

				// just parse an integer for the exponent portion
				let intPortion = StringView(str, sc);
				let intResult = ParseNumber(intPortion);

				if(intResult case .Ok(let val))
				{
					// more accurate than Math.Pow, but also way stupider

					if( val < 0 )
					{
						double div = 1;

						for(int i = 0; i < -val; i++ )
							div *= 10;

						curVal /= div;
					}
					else
					{
						double mul = 1;

						for(int i = 0; i < val; i++ )
							mul *= 10;

						curVal *= mul;
					}
				}
				else
				{
					return .Err;
				}
			}

			if(negative)
				curVal *= -1;

			return curVal;
		}

		private static bool IsHex(char32 r)
		{
			return (r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F');
		}

		private static bool IsOct(char32 r)
		{
			return r >= '0' && r <= '7';
		}

		private static bool IsBin(char32 r)
		{
			return r == '0' || r == '1';
		}
	}
}
