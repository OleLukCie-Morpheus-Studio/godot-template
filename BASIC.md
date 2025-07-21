What are Nodes and Scenes?

	~ Nodes are the building blocks of Godot.
		There are many different types of Nodes, each with a specific function.
		Example: The player`s image, a sound effect.


	~ Scenes are a collection of Nodes.
		Example: The player character, a level.


What is Programming?

	~ Programming is the process of writing instructions for the computer to follow.

	~ These instructions control what happens when the game is running.

	~ Examples: Moving the player when you press a button, losing HP when enemy hits the player.

	~ These instructions are written using programming languages.

	~ Every programming language has its own features and ways to write code.

	~ Godot uses its own programming language called GDScript.


What are Assets?

	~ Game Assets are the individual components that make up a game`s world.

	~ They include sprites, music, animations, etc.


What are variables?

	~ Variables are containers that can store many different types of data.

Using Variables

	~ Use variables like position and scale.

	~ These variables that already exist are called built-in variables.

Creating Variables

	~ We often have to make our own variables to store useful data.

	~ Creating a variable

	~ You can create the variable and set it later.

Naming Variables

	~ Not all variable names are valid.

Variable Types

	~ Here are the most common variable types:

		Strings("Hello World!")

		Integers(5,24,5000)

		Floats(0.123,12.6)

		Booleans(true,false)

	~ We can enforce the type of a variable when creating one. This makes them easier to understand and use in the future.


What`s an "If Statement"?

	~ An if statement is a block of code that runs when a condition is true.


What is a Vector2?

	~ A Vector2 is a type of variable that contains two floats inside of it.

	~ These Vectors are usually represented as (X,Y)

	~ We already used Vector2 before, such as position and scale.

	~ Input.get_vector(...) gives us a Vector2

	~ It shows us the direction the player is moving in.


Elif Statements

	~ elif (else if) statements are used to check if something else is true after a false if statement.

	~ You can chain multiple elif statements together. The first one to be true will run, ignoring the rest.


Else Statements

	~ An else statement automatically runs if the statements above it are all false.


Introducing Tilemaps

	~ A Tilemap is an incredibly popular technique in 2D games that allows you to create a level by placing blocks(called Tiles).


What are Signals?

	~ Signals are a way to run specific parts of code whenever an event happens.

	~ For example, we could have a signal that emits when the player touches a coin, or when the user clicks a button.

	~ Every node has its own set of signals, which you can be connected to any script in the scene, including ones on other nodes.


Autoloads

	~ Autoloads are nodes that always exist and don`t get deleted when switching scenes.

	~ We can create an autoload to hold a variable for where the player should spawn.

	SceneEntrance tells ScreneManager where the player should spawn.
	We change the scene.
	The player spawns wherever SceneManager tells it to.