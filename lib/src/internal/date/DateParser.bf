using System;
using System.Diagnostics;

namespace JetFistGames.Toml.Internal
{
	static class DateParser
	{
		private static int ScanInt(StringView str, out int value)
		{
			int sc = 0, sl = str.Length;

			int curVal = 0;
			bool negative = false;

			if(str[sc] == '-')
			{
				negative = true;
				sc++;
			}

			while(sc < sl)
			{
				char8 ch = str[sc++];

				if(!ch.IsDigit) break;

				int digit = (int)(ch - '0');
				curVal = ( curVal * 10 ) + digit;
			}

			if(negative)
				curVal *= -1;

			value = curVal;
			return sc - 1;
		}

		private static int ScanFloat(StringView str, out float value)
		{
			int sc = 0, sl = str.Length;

			float curVal = 0;
			bool negative = false;

			if(str[sc] == '-')
			{
				negative = true;
				sc++;
			}

			if(str[sc] != '.')
			{
				while(sc < sl)
				{
					char8 ch = str[sc];
	
					if(!ch.IsDigit) break;
	
					int digit = (int)(ch - '0');
					curVal = ( curVal * 10 ) + digit;

					sc++;
				}
			}

			// fractional?
			if(sc < sl && str[sc] == '.')
			{
				sc++;

				float curFrac = 0.1f;

				while(sc < sl)
				{
					char8 ch = str[sc++];

					if(!ch.IsDigit) break;

					int digit = (int)(ch - '0');
					curVal += curFrac * digit;

					curFrac *= 0.1f;
				}
			}

			if(negative)
				curVal *= -1;

			value = curVal;
			return sc - 1;
		}

		public static void Scan(StringView str, StringView format, params void*[] outArgs)
		{
			int pc = 0, pl = format.Length, sc = 0, sl = str.Length;
			int curArg = 0;

			char8 fmt = format[pc];

			while(pc < pl && sc < sl)
			{
				fmt = format[pc];

				if(fmt == '%')
				{
					// format prefix, advance character and check type code
					pc++;
					if( pc >= pl ) return;

					fmt = format[pc];

					switch(fmt)
					{
					case 'd':
						// parse integer from string
						int val;
						sc += ScanInt(StringView(str, sc), out val);
						*(int*)outArgs[curArg++] = val;
						pc++;
						continue;
					case 'f':
						// parse decimal from string
						float val;
						sc += ScanFloat(StringView(str, sc), out val);
						*(float*)outArgs[curArg++] = val;
						pc++;
						continue;
					case '%':
						// literal % character
						pc++;
						sc++;
						continue;
					default: Debug.FatalError(scope String()..AppendF("Invalid format code: %{0}", fmt));
					}
				}
				else
				{
					pc++;
					sc++;
					continue;
				}
			}
		}

		private static bool MatchPattern(StringView s, StringView pattern)
		{
			int pc = 0, pl = pattern.Length, sc = 0, sl = s.Length;

			while(pc < pl && sc < sl)
			{
				char8 code = pattern[pc];
				char8 ch = s[sc];

				if(code == 'd')
				{
					if( !ch.IsDigit )
					{
						return false;
					}

					pc++;
					sc++;
					continue;
				}
				if(code == 'f')
				{
					if(pc >= pl || sc >= sl || !ch.IsDigit)
					{
						return false;
					}

					sc++;
					ch = s[sc];

					if(pc >= pl || sc >= sl || !ch.IsDigit)
					{
						return false;
					}

					sc++;
					ch = s[sc];

					if(pc >= pl || sc >= sl || ch != '.')
					{
						pc++;
						continue;
					}

					sc++;
					ch = s[sc];

					while(ch.IsDigit)
					{
						sc++;
						if(sc >= sl)
							break;

						ch = s[sc];
					}

					pc++;
					continue;
				}
				if(code == ':' || code == '-' || code == '+' || code == 't' || code == 'z' || code == ' ')
				{
					if(code != ch)
					{
						return false;
					}

					sc++;
					pc++;
					continue;
				}
				return false;
			}

			if(sc != sl || pc != pl)
			{
				return false;
			}

			return true;
		}

		public static Result<DateTime> Parse(StringView str)
		{
			let dateStr = scope String(str);
			dateStr.ToLower();
			
			// YYYY-MM-DD
			if(MatchPattern(dateStr, "dddd-dd-dd"))
			{
				int year = 0, month = 0, day = 0;
				Scan(dateStr, "%d-%d-%d", &year, &month, &day);

				return DateTime.SpecifyKind( DateTime(year, month, day), DateTimeKind.Local );
			}

			// HH:MM:SS
			if(MatchPattern(dateStr, "dd:dd:f"))
			{
				int hour = 0, minute = 0;
				float second = 0f;
				Scan(dateStr, "%d:%d:%f", &hour, &minute, &second);

				return DateTime.SpecifyKind( DateTime().AddHours(hour).AddMinutes(minute).AddSeconds(second), DateTimeKind.Local );
			}
			
			// YYYY-MM-DDtHH:MM:SS
			// YYYY-MM-DD HH:MM:SS
			if(MatchPattern(dateStr, "dddd-dd-ddtdd:dd:f") || MatchPattern(dateStr, "dddd-dd-dd dd:dd:f"))
			{
				int year = 0, month = 0, day = 0, hour = 0, minute = 0;
				float second = 0f;
				Scan(dateStr, "%d-%d-%d %d:%d:%f", &year, &month, &day, &hour, &minute, &second);

				return DateTime.SpecifyKind( DateTime(year, month, day)
					.AddHours(hour)
					.AddMinutes(minute)
					.AddSeconds(second), DateTimeKind.Local );
			}

			// YYYY-MM-DDtHH:MM:SSz
			// YYYY-MM-DD HH:MM:SSz
			if(MatchPattern(dateStr, "dddd-dd-ddtdd:dd:fz") || MatchPattern(dateStr, "dddd-dd-dd dd:dd:fz"))
			{
				int year = 0, month = 0, day = 0, hour = 0, minute = 0;
				float second = 0f;
				Scan(dateStr, "%d-%d-%d %d:%d:%f", &year, &month, &day, &hour, &minute, &second);

				return DateTime.SpecifyKind( DateTime(year, month, day)
					.AddHours(hour)
					.AddMinutes(minute)
					.AddSeconds(second), DateTimeKind.Utc );
			}

			// YYYY-MM-DDtHH:MM:SS-00:00
			// YYYY-MM-DD HH:MM:SS-00:00
			if(MatchPattern(dateStr, "dddd-dd-ddtdd:dd:f-00:00") || MatchPattern(dateStr, "dddd-dd-dd dd:dd:f-00:00"))
			{
				int year = 0, month = 0, day = 0, hour = 0, minute = 0;
				float second = 0f;
				Scan(dateStr, "%d-%d-%d %d:%d:%f", &year, &month, &day, &hour, &minute, &second);

				return DateTime.SpecifyKind( DateTime(year, month, day)
					.AddHours(hour)
					.AddMinutes(minute)
					.AddSeconds(second), DateTimeKind.Unspecified );
			}

			// YYYY-MM-DDtHH:MM:SS+hh:mm
			// YYYY-MM-DD HH:MM:SS+hh:mm
			if(MatchPattern(dateStr, "dddd-dd-ddtdd:dd:f+dd:f") || MatchPattern(dateStr, "dddd-dd-dd dd:dd:f+dd:f"))
			{
				int year = 0, month = 0, day = 0, hour = 0, minute = 0, offsetH = 0;
				float second = 0f, offsetM = 0f;
				Scan(dateStr, "%d-%d-%d %d:%d:%f+%d:%f", &year, &month, &day, &hour, &minute, &second, &offsetH, &offsetM);

				return DateTime.SpecifyKind( DateTime(year, month, day)
					.AddHours(hour)
					.AddMinutes(minute)
					.AddSeconds(second)
					.AddHours(-offsetH)
					.AddMinutes(-offsetM), DateTimeKind.Utc );
			}

			// YYYY-MM-DDtHH:MM:SS-hh:mm
			// YYYY-MM-DD HH:MM:SS-hh:mm
			if(MatchPattern(dateStr, "dddd-dd-ddtdd:dd:f-dd:f") || MatchPattern(dateStr, "dddd-dd-dd dd:dd:f-dd:f"))
			{
				int year = 0, month = 0, day = 0, hour = 0, minute = 0, offsetH = 0;
				float second = 0f, offsetM = 0f;
				Scan(dateStr, "%d-%d-%d %d:%d:%f-%d:%f", &year, &month, &day, &hour, &minute, &second, &offsetH, &offsetM);

				if( offsetH < 0 )
					offsetH = -offsetH;

				return DateTime.SpecifyKind( DateTime(year, month, day)
					.AddHours(hour)
					.AddMinutes(minute)
					.AddSeconds(second)
					.AddHours(offsetH)
					.AddMinutes(offsetM), DateTimeKind.Utc );
			}

			return .Err;
		}
	}
}
