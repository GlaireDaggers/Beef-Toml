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
	}
}
