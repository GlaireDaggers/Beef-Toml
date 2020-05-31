using System;

namespace JetFistGames.Toml.Internal
{
	enum TokenType
	{
		Invalid,

		EOF,
		Text,
		String,
		RawString,
		MultilineString,
		RawMultilineString,
		Bool,
		Integer,
		Float,
		Datetime,
		Array,
		ArrayEnd,
		TableStart,
		TableEnd,
		ArrayTableStart,
		ArrayTableEnd,
		KeyStart,
		CommentStart,
		InlineTableStart,
		InlineTableEnd,
	}

	struct Token
	{
		public readonly TokenType Kind;
		public readonly int Line;
		public readonly StringView Value;

		public this(TokenType tokenType, int line, StringView value = "")
		{
			Kind = tokenType;
			Line = line;
			Value = value;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("{0} ({1}, line {2})", Value, Kind, Line);
		}
	}
}
