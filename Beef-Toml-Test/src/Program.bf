using System;
using JetFistGames.Toml;

namespace Beef_Toml_Test
{
	class Program
	{
		public static void Main(String[] args)
		{
			String test = """
# This is a TOML document.

title = "TOML Example"

[owner]
name = "Tom Preston-Werner"
dob = 1979-05-27T07:32:00-08:00 # First class dates

[database]
server = "192.168.1.1"
ports = [ 8001, 8001, 8002 ]
connection_max = 5000
enabled = true

[servers]

  # Indentation (tabs and/or spaces) is allowed but not required
  [servers.alpha]
  ip = "10.0.0.1"
  dc = "eqdc10"

  [servers.beta]
  ip = "10.0.0.2"
  dc = "eqdc10"

[clients]
data = [ ["gamma", "delta"], [1, 2] ]

# Line breaks are OK when inside arrays
hosts = [
  "alpha",
  "omega"
]
""";

			let result = TomlSerializer.Read(test);

			if (result case .Err(let err))
			{
				Console.WriteLine("Failed to parse!");
				Console.WriteLine(err);
			}
			else if(result case .Ok(let doc))
			{
				Console.WriteLine("Parse successful!");
				Console.WriteLine(doc["owner.name"].GetString().Value);

				String dateStr = scope String();
				doc["owner.dob"].GetDatetime().Value.ToString(dateStr);
				Console.WriteLine(dateStr);

				Console.WriteLine(doc["database.server"].GetString().Value);
				Console.WriteLine(doc["database.ports"][0].GetInt().Value);
				Console.WriteLine(doc["database.connection_max"].GetInt().Value);
				Console.WriteLine(doc["database.enabled"].GetBool().Value);
				Console.WriteLine(doc["clients.hosts"][1].GetString().Value);
				delete doc;
			}

			var doc = new TomlTableNode();
			doc.AddChild<TomlValueNode>("myKey").SetString("Hello, world!");
			doc.AddChild<TomlArrayNode>("myArray").AddChild<TomlValueNode>().SetInt(100);

			var docStr = scope String();
			TomlSerializer.Write(doc, docStr);

			Console.WriteLine(docStr);
			delete doc;

			Console.In.Read();
		}
	}
}
