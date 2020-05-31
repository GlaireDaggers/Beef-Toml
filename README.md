# Beef-Toml
A simple TOML serializer/deserializer for the [Beef programming language](www.beeflang.org)

## Usage

### Parsing a TOML document string

    using JetFistGames.Toml;
    
    // ...
    
    let result = TomlSerializer.Read(tomlDocumentString);
    
    if (result case .Err(let err))
    {
        Console.WriteLine(scope String()..AppendF("TOML parse failed: {0}", err));
    }
    else if (result case .Ok(let doc))
    {
        // query the TOML document tree nodes using dot notation
       Console.WriteLine(doc["table.key"].GetString().Value);
        
        // index array nodes
        let tomlArray = doc["table.arrayKey"].GetArray().Value;
        for(int i = 0; i < tomlArray.Count; i++)
        {
          Console.WriteLine(tomlArray[i].GetInt().Value);
        }
    
        delete doc; // remember to delete the allocated TOML document tree when you're finished!
    }

### Serializing a TOML document to string

    using JetFistGames.Toml;
    
    // ...
    
    var doc = new TomlTableNode();
    doc.AddChild<TomlValueNode>("myKey").SetString("Hello, world!");
    doc.AddChild<TomlArrayNode>("myArray").AddChild<TomlValueNode>().SetInt(100);
    
    var docStr = scope String();
    TomlSerializer.Write(doc, docStr);
    
    // myKey = "Hello, world!";
    // myArray = [ 100 ]
    
    delete doc;
    
### TomlNode Get/set value types

    TomlNode.GetString();   // Result<String>
    TomlNode.GetInt();      // Result<int>
    TomlNode.GetFloat();    // Result<float>
    TomlNode.GetBool();     // Result<bool>
    TomlNode.GetDatetime(); // Result<DateTime>
    TomlNode.GetTable();    // Result<TomlTableNode>
    TomlNode.GetArray();    // Result<TomlArrayNode>
    
    TomlValueNode.SetString( value );
    TomlValueNode.SetInt( value );
    TomlValueNode.SetFloat( value );
    TomlValueNode.SetBool( value );
    TomlValueNode.SetDatetime( value );
    
### Notes
At the moment it only supports querying a document tree, but reflection-based automatic serialization/deserialization is planned (I'd like to eventually allow for something like `TomlSerializer.Deserialize<MyType>( inTomlString, outMyObject )` and `TomlSerializer.Serialize( inMyObject, outTomlString )`.

Beef-Toml is currently developed and tested against Beef nightly build v0.42.5 (05/30/2020). There is a bug in the publicly available release 0.42.4 which prevents Beef-Toml from compiling, this has been fixed in the nightly builds.
