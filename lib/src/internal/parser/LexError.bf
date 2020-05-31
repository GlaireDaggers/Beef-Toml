using System;

namespace JetFistGames.Toml
{
	struct TomlError : IDisposable
	{
		public String Message;
		public int Line;

		public this(int line, String fmt)
		{
			Line = line;
			Message = new String();
			Message.Set(fmt);
		}

		public this(int line, String fmt, params Object[] args)
		{
			Line = line;
			Message = new String();
			Message.AppendF(fmt, params args);
		}

		public void Dispose()
		{
			if (Message != null)
				delete Message;
		}

		public override void ToString(String strBuffer)
		{
			strBuffer.AppendF("{0} (line {1})", Message, Line + 1);
		}
	}
}
