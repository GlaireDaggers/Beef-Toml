namespace JetFistGames.Toml.Internal
{
	struct TextPosition
	{
		public int Offset;
		public int Column;
		public int Line;

		public override void ToString(System.String strBuffer)
		{
			strBuffer.AppendF("Ln {0} Col {1}", Line, Column);
		}
	}
}
