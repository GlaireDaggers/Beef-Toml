using System;
using System.Diagnostics;
using JetFistGames.Toml;

namespace BeefTomlTests
{
	class Tests
	{
		static void AssertFmt(bool condition, StringView fmt, params Object[] args)
		{
			if(!condition)
			{
				let str = scope String();
				str.AppendF(fmt, params args);
				Test.FatalError(str);
			}
		}

		static mixin CheckParse(StringView inStr)
		{
			let result = TomlSerializer.Read(inStr);

			if(result case .Err(let err))
			{
				let str = scope String();
				err.ToString(str);
				Test.FatalError(str);
			}

			(TomlNode)result.Value
		}

		static mixin CheckTableValue(var src)
		{
			Test.Assert(src case .Ok);
		}

		static mixin CheckTableValue(var src, var check)
		{
			Test.Assert(src case .Ok);
			AssertFmt(src.Value == check, "Expected: ({0}), got: ({1})", check, src.Value);
		}

		static mixin CheckTableArray(Result<TomlArrayNode> src, int length)
		{
			Test.Assert(src case .Ok);
			AssertFmt(src.Value.Count == length, "Expected {0} elements but got {1}", length, src.Value.Count);
		}

		static mixin CheckTableValue(Result<DateTime> src, DateTime check)
		{
			Test.Assert(src case .Ok);
			let str1 = scope String();
			let str2 = scope String();
			src.Value.ToLongDateString(str1);
			check.ToLongDateString(str2);
			AssertFmt(src.Value == check, "Expected: ({0}), got: ({1})", str2, str1);
		}

		static mixin CheckTableValueApprox(Result<double> src, double check)
		{
			Test.Assert(src case .Ok);
			AssertFmt(Math.Abs(src.Value - check) <= double.Epsilon, "Expected: ({0}), got: ({1})", check, src.Value);
		}

		static DateTime CreateUTC(int year, int month, int day, int hour, int minute, int second, int millisecond, float offset)
		{
			DateTime dt = DateTime(year, month, day, hour, minute, second, millisecond);
			dt = DateTime.SpecifyKind(dt, .Utc);
			dt = dt.AddHours(-offset);

			return dt;
		}

		[Test]
		static void TestComments()
		{
			let docStr = """
# this is a comment
key1 = \"value\" # this is another comment
key2 = \"# this is not a comment\"
""";

			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["key1"].GetString(), "value");
			CheckTableValue!(doc["key2"].GetString(), "# this is not a comment");

			delete doc;
		}

		[Test]
		static void TestKeys()
		{
			let docStr = """
bareKey1 = \"value1\"
1234 = \"value2\"
\"quoted key\" = \"value3\"
'quoted \"key\"' = \"value4\"
""";

			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["bareKey1"].GetString(), "value1");
			CheckTableValue!(doc["1234"].GetString(), "value2");
			CheckTableValue!(doc["quoted key"].GetString(), "value3");
			CheckTableValue!(doc["quoted \"key\""].GetString(), "value4");

			delete doc;
		}

		[Test]
		static void TestDottedKeys()
		{
			let docStr = """
name = \"Orange\"
physical.color = \"orange\"
physical.shape = \"round\"
site.\"google.com\" = true
spaces . in . keys = \"wow\"
""";
			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["name"].GetString(), "Orange");
			CheckTableValue!(doc["physical"]["color"].GetString(), "orange");
			CheckTableValue!(doc["physical"]["shape"].GetString(), "round");
			CheckTableValue!(doc["site"]["google.com"].GetBool(), true);
			CheckTableValue!(doc["spaces"]["in"]["keys"].GetString(), "wow");

			delete doc;
		}

		[Test]
		static void TestStrings()
		{
			let docStr = """
str1 = \"I'm a string. \\\"You can quote me\\\". Name\\tJos\\u00E9\\nLocation\\tSF.\"
str2 = \"\"\"
Roses are red.
Violets are blue.\"\"\"
str3 = \"\"\"
	The quick brown \\
	fox jumps over \\
	the lazy dog.\\
	\"\"\"
str4 = \"\"\"Here are two quotation marks: \"\". Simple enough.\"\"\"
str5 = \"\"\"Here are three quotation marks: \"\"\\\".\"\"\"
str6 = \"\"\"Here are fifteen quotation marks: \"\"\\\"\"\"\\\"\"\"\\\"\"\"\\\"\"\"\\\".\"\"\"
str7 = \"\"\"\"This,\" she said, \"is just a pointless statement.\"\"\"\"
winpath = 'C:\\Users\\nodejs\\templates'
winpath2 = '\\\\ServerX\\admin$\\system32\\'
quoted = 'Tom \"Dubs\" Preston-Werner'
regex = '<\\i\\c*\\s*>'
regex2 = '''I [dw]on't need \\d{2} apples'''
lines = '''
The first newline is
trimmed in raw strings.
	All other whitespace
	is preserved.
'''
quot15 = '''Here are fifteen quotation marks: \"\"\"\"\"\"\"\"\"\"\"\"\"\"\"'''
apos15 = \"Here are fifteen apostrophes: '''''''''''''''\"
str8 = ''''That,' she said, 'is still pointless.''''
""";

			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["str1"].GetString(), "I'm a string. \"You can quote me\". Name\tJos\u{00E9}\nLocation\tSF.");
			CheckTableValue!(doc["str2"].GetString(), "Roses are red.\nViolets are blue.");
			CheckTableValue!(doc["str3"].GetString(), "\tThe quick brown fox jumps over the lazy dog.");
			CheckTableValue!(doc["str4"].GetString(), "Here are two quotation marks: \"\". Simple enough.");
			CheckTableValue!(doc["str5"].GetString(), "Here are three quotation marks: \"\"\".");
			CheckTableValue!(doc["str6"].GetString(), "Here are fifteen quotation marks: \"\"\"\"\"\"\"\"\"\"\"\"\"\"\".");
			CheckTableValue!(doc["str7"].GetString(), "\"This,\" she said, \"is just a pointless statement.\"");
			CheckTableValue!(doc["winpath"].GetString(), "C:\\Users\\nodejs\\templates");
			CheckTableValue!(doc["winpath2"].GetString(), "\\\\ServerX\\admin$\\system32\\");
			CheckTableValue!(doc["quoted"].GetString(), "Tom \"Dubs\" Preston-Werner");
			CheckTableValue!(doc["regex"].GetString(), "<\\i\\c*\\s*>");
			CheckTableValue!(doc["regex2"].GetString(), "I [dw]on't need \\d{2} apples");
			CheckTableValue!(doc["lines"].GetString(), "The first newline is\ntrimmed in raw strings.\n\tAll other whitespace\n\tis preserved.\n");
			CheckTableValue!(doc["quot15"].GetString(), "Here are fifteen quotation marks: \"\"\"\"\"\"\"\"\"\"\"\"\"\"\"");
			CheckTableValue!(doc["apos15"].GetString(), "Here are fifteen apostrophes: '''''''''''''''");
			CheckTableValue!(doc["str8"].GetString(), "'That,' she said, 'is still pointless.'");

			delete doc;
		}

		[Test]
		static void TestIntegers()
		{
			let docStr = """
int1 = +99
int2 = 42
int3 = 0
int4 = -17
int5 = 1_000
int6 = 5_349_221
int7 = 1_2_3_4_5
hex1 = 0xDEADBEEF
hex2 = 0xdeadbeef
hex3 = 0xdead_beef
oct1 = 0o01234567
oct2 = 0o755
bin1 = 0b11010110
""";

			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["int1"].GetInt(), 99);
			CheckTableValue!(doc["int2"].GetInt(), 42);
			CheckTableValue!(doc["int3"].GetInt(), 0);
			CheckTableValue!(doc["int4"].GetInt(), -17);
			CheckTableValue!(doc["int5"].GetInt(), 1000);
			CheckTableValue!(doc["int6"].GetInt(), 5349221);
			CheckTableValue!(doc["int7"].GetInt(), 12345);
			CheckTableValue!(doc["hex1"].GetInt(), 0xDEADBEEF);
			CheckTableValue!(doc["hex2"].GetInt(), 0xDEADBEEF);
			CheckTableValue!(doc["hex3"].GetInt(), 0xDEADBEEF);
			CheckTableValue!(doc["oct1"].GetInt(), 0o01234567);
			CheckTableValue!(doc["oct2"].GetInt(), 0o755);
			CheckTableValue!(doc["bin1"].GetInt(), 0b11010110);

			delete doc;
		}

		[Test]
		static void TestFloats()
		{
			let docStr = """
flt1 = +1.0
flt2 = 3.1415
flt3 = -0.01
flt4 = 5e+22
flt5 = 1e06
flt6 = -2E-2
flt7 = 6.626e-34
flt8 = 224_617.445_991_228
sf1 = inf
sf2 = +inf
sf3 = -inf
sf4 = nan
sf5 = +nan
sf6 = -nan
""";

			let doc = CheckParse!(docStr);

			CheckTableValueApprox!(doc["flt1"].GetFloat(), 1.0);
			CheckTableValueApprox!(doc["flt2"].GetFloat(), 3.1415);
			CheckTableValueApprox!(doc["flt3"].GetFloat(), -0.01);
			CheckTableValueApprox!(doc["flt4"].GetFloat(), 5e+22);
			CheckTableValueApprox!(doc["flt5"].GetFloat(), 1e+6);
			CheckTableValueApprox!(doc["flt6"].GetFloat(), -2e-2);
			CheckTableValueApprox!(doc["flt7"].GetFloat(), 6.626e-34);
			CheckTableValueApprox!(doc["flt8"].GetFloat(), 224617.445991228);
			CheckTableValue!(doc["sf1"].GetFloat(), double.PositiveInfinity);
			CheckTableValue!(doc["sf2"].GetFloat(), double.PositiveInfinity);
			CheckTableValue!(doc["sf3"].GetFloat(), double.NegativeInfinity);
			CheckTableValue!(doc["sf4"].GetFloat(), double.NaN);
			CheckTableValue!(doc["sf5"].GetFloat(), double.NaN);
			CheckTableValue!(doc["sf6"].GetFloat(), double.NaN);

			delete doc;
		}

		[Test]
		static void TestBoolean()
		{
			let docStr = """
bool1 = true
bool2 = false
""";

			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["bool1"].GetBool(), true);
			CheckTableValue!(doc["bool2"].GetBool(), false);

			delete doc;
		}

		[Test]
		static void TestDates()
		{
			let docStr = """
odt1 = 1979-05-27T07:32:00Z
odt2 = 1979-05-27T00:32:00-07:00
odt3 = 1979-05-27T00:32:00.999999-07:00
odt4 = 1979-05-27 07:32:00Z
ldt1 = 1979-05-27T07:32:00
ldt2 = 1979-05-27T00:32:00.999999
ld1 = 1979-05-27
lt1 = 07:32:00
lt2 = 00:32:00.999999
""";

			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["odt1"].GetDatetime(), CreateUTC(1979, 5, 27, 7, 32, 0, 0, 0f));
			CheckTableValue!(doc["odt2"].GetDatetime(), CreateUTC(1979, 5, 27, 0, 32, 0, 0, -7f));
			CheckTableValue!(doc["odt3"].GetDatetime(), CreateUTC(1979, 5, 27, 0, 32, 0, 0, -7f).AddSeconds(0.999999));
			CheckTableValue!(doc["odt4"].GetDatetime(), CreateUTC(1979, 5, 27, 7, 32, 0, 0, 0f));
			CheckTableValue!(doc["ldt1"].GetDatetime(), DateTime(1979, 5, 27, 7, 32, 0, 0));
			CheckTableValue!(doc["ldt2"].GetDatetime(), DateTime(1979, 5, 27, 0, 32, 0, 0).AddSeconds(0.999999));
			CheckTableValue!(doc["ld1"].GetDatetime(), DateTime(1979, 5, 27));
			CheckTableValue!(doc["lt1"].GetDatetime(), DateTime().AddHours(7).AddMinutes(32));
			CheckTableValue!(doc["lt2"].GetDatetime(), DateTime().AddMinutes(32).AddSeconds(0.999999));

			delete doc;
		}

		[Test]
		static void TestArrays()
		{
			let docStr = """
integers = [ 1, 2, 3 ]
colors = [ "red", "yellow", "green" ]
nested_array_of_int = [ [1,2], [3,4,5] ]
nested_mixed_array = [ [1,2,3], ["a", "b", "c"] ]
string_array = [ "all", 'strings', \"\"\"are the same\"\"\", '''type''' ]
numbers = [ 0.1, 0.2, 0.5, 1, 2, 5 ]
contributors = [
	"Foo Bar <foo@example.com>",
	{ name = "Baz Qux", email = "bazqux@example.com", url = "https://example.com/bazqux" }
]
""";

			let doc = CheckParse!(docStr);

			CheckTableArray!(doc["integers"].GetArray(), 3);
			CheckTableValue!(doc["integers"][0].GetInt(), 1);
			CheckTableValue!(doc["integers"][1].GetInt(), 2);
			CheckTableValue!(doc["integers"][2].GetInt(), 3);

			CheckTableArray!(doc["colors"].GetArray(), 3);
			CheckTableValue!(doc["colors"][0].GetString(), "red");
			CheckTableValue!(doc["colors"][1].GetString(), "yellow");
			CheckTableValue!(doc["colors"][2].GetString(), "green");

			CheckTableArray!(doc["nested_array_of_int"].GetArray(), 2);
			CheckTableArray!(doc["nested_array_of_int"][0].GetArray(), 2);
			CheckTableArray!(doc["nested_array_of_int"][1].GetArray(), 3);

			CheckTableValue!(doc["nested_array_of_int"][0][0].GetInt(), 1);
			CheckTableValue!(doc["nested_array_of_int"][0][1].GetInt(), 2);

			CheckTableValue!(doc["nested_array_of_int"][1][0].GetInt(), 3);
			CheckTableValue!(doc["nested_array_of_int"][1][1].GetInt(), 4);
			CheckTableValue!(doc["nested_array_of_int"][1][2].GetInt(), 5);

			CheckTableArray!(doc["nested_mixed_array"].GetArray(), 2);
			CheckTableArray!(doc["nested_mixed_array"][0].GetArray(), 3);
			CheckTableArray!(doc["nested_mixed_array"][1].GetArray(), 3);

			CheckTableValue!(doc["nested_mixed_array"][0][0].GetInt(), 1);
			CheckTableValue!(doc["nested_mixed_array"][0][1].GetInt(), 2);
			CheckTableValue!(doc["nested_mixed_array"][0][2].GetInt(), 3);

			CheckTableValue!(doc["nested_mixed_array"][1][0].GetString(), "a");
			CheckTableValue!(doc["nested_mixed_array"][1][1].GetString(), "b");
			CheckTableValue!(doc["nested_mixed_array"][1][2].GetString(), "c");

			CheckTableArray!(doc["string_array"].GetArray(), 4);
			CheckTableValue!(doc["string_array"][0].GetString(), "all");
			CheckTableValue!(doc["string_array"][1].GetString(), "strings");
			CheckTableValue!(doc["string_array"][2].GetString(), "are the same");
			CheckTableValue!(doc["string_array"][3].GetString(), "type");

			CheckTableArray!(doc["contributors"].GetArray(), 2);
			CheckTableValue!(doc["contributors"][0].GetString(), "Foo Bar <foo@example.com>");

			CheckTableValue!(doc["contributors"][1].GetTable());

			CheckTableValue!(doc["contributors"][1]["name"].GetString(), "Baz Qux");
			CheckTableValue!(doc["contributors"][1]["email"].GetString(), "bazqux@example.com");
			CheckTableValue!(doc["contributors"][1]["url"].GetString(), "https://example.com/bazqux");

			delete doc;
		}

		[Test]
		static void TestTables()
		{
			let docStr = """
[table]

[table-1]
key1 = "some string"
key2 = 123

[table-2]
key1 = "another string"
key2 = 456

[dog."tater.man"]
type.name = "pug"

[a . b . c]

[ j . "ʞ" . 'l' ]

[x.y.z.w]

[x]
val = 100

[fruit]
apple.color = "red"
apple.taste.sweet = true

[fruit.apple.texture]
smooth = true
""";

			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["table"].GetTable());
			CheckTableValue!(doc["table-1"]["key1"].GetString(), "some string");
			CheckTableValue!(doc["table-2"]["key1"].GetString(), "another string");
			CheckTableValue!(doc["dog"]["tater.man"]["type"]["name"].GetString(), "pug");
			CheckTableValue!(doc["a"]["b"]["c"].GetTable());
			CheckTableValue!(doc["j"]["ʞ"]["l"].GetTable());
			CheckTableValue!(doc["x"]["y"]["z"]["w"].GetTable());
			CheckTableValue!(doc["x"]["val"].GetInt(), 100);
			CheckTableValue!(doc["fruit"]["apple"]["color"].GetString(), "red");
			CheckTableValue!(doc["fruit"]["apple"]["taste"]["sweet"].GetBool(), true);
			CheckTableValue!(doc["fruit"]["apple"]["texture"]["smooth"].GetBool(), true);

			delete doc;
		}

		[Test]
		static void TestInlineTables()
		{
			let docStr = """
name = { first = "Tom", last = "Preston-Werner" }
point = { x = 1, y = 2 }
animal = { type.name = "pug" }
""";

			let doc = CheckParse!(docStr);

			CheckTableValue!(doc["name"]["first"].GetString(), "Tom");
			CheckTableValue!(doc["name"]["last"].GetString(), "Preston-Werner");
			CheckTableValue!(doc["point"]["x"].GetInt(), 1);
			CheckTableValue!(doc["point"]["y"].GetInt(), 2);
			CheckTableValue!(doc["animal"]["type"]["name"].GetString(), "pug");

			delete doc;
		}

		[Test]
		static void TestArrayTables()
		{
			let docStr = """
[[products]]
name = "Hammer"
sku = 738594937

[[products]]

[[products]]
name = "Nail"
sku = 284758393

color = "gray"

[[fruit]]
name = "apple"

[fruit.physical]  # subtable
color = "red"
shape = "round"

[[fruit.variety]]  # nested array of tables
name = "red delicious"

[[fruit.variety]]
name = "granny smith"

[[fruit]]
name = "banana"

[[fruit.variety]]
name = "plantain"
""";

			let doc = CheckParse!(docStr);

			CheckTableArray!(doc["products"].GetArray(), 3);
			CheckTableValue!(doc["products"][0]["name"].GetString(), "Hammer");
			CheckTableValue!(doc["products"][0]["sku"].GetInt(), 738594937);
			CheckTableValue!(doc["products"][2]["name"].GetString(), "Nail");
			CheckTableValue!(doc["products"][2]["sku"].GetInt(), 284758393);
			CheckTableValue!(doc["products"][2]["color"].GetString(), "gray");

			CheckTableArray!(doc["fruit"].GetArray(), 2);
			CheckTableValue!(doc["fruit"][0]["name"].GetString(), "apple");
			CheckTableValue!(doc["fruit"][0]["physical"]["color"].GetString(), "red");
			CheckTableValue!(doc["fruit"][0]["physical"]["shape"].GetString(), "round");
			CheckTableArray!(doc["fruit"][0]["variety"].GetArray(), 2);
			CheckTableValue!(doc["fruit"][0]["variety"][0]["name"].GetString(), "red delicious");
			CheckTableValue!(doc["fruit"][0]["variety"][1]["name"].GetString(), "granny smith");

			CheckTableValue!(doc["fruit"][1]["name"].GetString(), "banana");
			CheckTableArray!(doc["fruit"][1]["variety"].GetArray(), 1);
			CheckTableValue!(doc["fruit"][1]["variety"][0]["name"].GetString(), "plantain");

			delete doc;
		}
	}
}
