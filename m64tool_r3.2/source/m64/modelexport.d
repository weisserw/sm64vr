module m64.modelexport;

import std.stream;
import std.string;
import std.math;
import std.path;
import m64.texture;
import m64.polygon;

interface IModel
{
	void exportTo(RdpStatus rdp, ModelExporter model);
}

struct ModelVertex
{
	double x, y, z, u, v;
}

/// Base class for all model exporter classes.
abstract class ModelExporter
{
	private double translationX = 0.0, translationY = 0.0, translationZ = 0.0;
	private double rotationX = 0.0, rotationY = 0.0, rotationZ = 0.0;

	/**
	 * Start defining a new object in the model (if possible).
	 *
	 * Params:
	 *	  name = The name of the object.
	 */
	abstract void createObject(string name);

	/**
	 * Write some comment on the model (if possible).
	 *
	 * Params:
	 *	  comment = The model to write.
	 */
	abstract void writeComment(string comment);

	/**
	 * Set a translation to apply to the next vertices.
	 */
	void addTranslation(double tX, double tY, double tZ)
	{
		translationX += tX;
		translationY += tY;
		translationZ += tZ;
	}
	
	/**
	 * Sets a rotation to apply to the next vertices.
	 */
	void addRotation(double rX, double rY, double rZ)
	{
		rotationX += rX;
		rotationY += rY;
		rotationZ += rZ;
	}

	/**
	 * Transforms a vertex using the currently applied operations.
	 */
	protected ModelVertex transformVertex(ModelVertex vtx)
	{
		double x = vtx.x;
		double y = vtx.y;
		double z = vtx.z;

		// Rotation around the X axis
		double x2 = x;
		double y2 = y * cos(rotationX) - z * sin(rotationX);
		double z2 = y * sin(rotationX) + z * cos(rotationX);

		// Rotation around the Y axis
		double x3 = z2 * sin(rotationY) + x2 * cos(rotationY);
		double y3 = y2;
		double z3 = z2 * cos(rotationY) - x2 * sin(rotationY);

		// Rotation around the Z axis
		double x4 = x3 * cos(rotationZ) - y3 * sin(rotationZ);
		double y4 = x3 * sin(rotationZ) + y3 * cos(rotationZ);
		double z4 = z3;

		// Translation
		ModelVertex tvtx;
		tvtx.x = translationX + x4;
		tvtx.y = translationY + y4;
		tvtx.z = translationZ + z4;
		tvtx.u = vtx.u;
		tvtx.v = vtx.v;
		return tvtx;		
	}

	/**
	 * Add a vertex to the vertex cache.
	 *
	 * Params:
	 *	  cacheIdx = Index in the cache of the vertex. In range [0, 16).
	 *	  vtx = The vertex to add in the cache.
	 */
	abstract void addVertexToCache(size_t cacheIdx, ModelVertex vtx);

	/**
	 * Create a triangular face using vertices previously defined in the vertex cache.
	 *
	 * Params:
	 *	  v1CacheIdx = Index in the cache of the first vertex.
	 *	  v2CacheIdx = Index in the cache of the second vertex.
	 *	  v3CacheIdx = Index in the cache of the third vertex.
	 */ 
	abstract void createFace(size_t v1CacheIdx, size_t v2CacheIdx, size_t v3CacheIdx);

	/**
	 * Sets the texture that should be used for the next faces.
	 *
	 * Params:
	 *	  tex = The texture to use.
	 */
	abstract void selectTexture(Texture tex);
}

import std.stdio;

/// A model exporter to the Wavefront .OBJ format.
class ObjExporter : ModelExporter
{
	/// The directory where the model will be saved.
	private string outputDirectory;
	/// The stream that contains the .OBJ (model definition) file.
	private Stream objFile;
	/// The stream that contains the .MTL (material definition) file.
	private Stream mtlFile;
	/// Contains the vertex index in the .OBJ file for each vertex in the cache.
	private size_t[16] vertexCacheToObjVertex;
	/// Index in the .OBJ file of the next vertex / current number of vertices.
	private int currentVertex = 1;
	/// Index in the .MTL file of the next material / current number of materials.
	private int currentMaterial = 1;
	/// Name of material associated to each texture.
	private string[Texture] textureCache;

	/**
	 * Create a new ObjExporter.
	 *
	 * Params:
	 *	  outputDirectory = Path where the model (and its textures) will be saved.
	 */
	this(string outputDirectory)
	{
		this.outputDirectory = outputDirectory;
		this.objFile = new std.stream.BufferedFile(buildPath(outputDirectory, "model.obj"), FileMode.OutNew);
		this.mtlFile = new std.stream.BufferedFile(buildPath(outputDirectory, "model.mtl"), FileMode.OutNew);

		this.objFile.writefln("mtllib model.mtl");
	}

	// Close all currently files.
	void close()
	{
		if (objFile !is null)
		{
			objFile.close();
			objFile = null;
		}

		if (mtlFile !is null)
		{
			mtlFile.close();
			mtlFile = null;
		}
	}

	override void createObject(string name)
	{
		objFile.writefln("o %s", name);
	}

	override void writeComment(string comment)
	{
		objFile.writefln("# %s", comment);
	}

	override void addVertexToCache(size_t cacheIdx, ModelVertex vtx)
	{
		vertexCacheToObjVertex[cacheIdx] = currentVertex++;

		vtx = transformVertex(vtx);
		objFile.writefln("v %f %f %f", vtx.x, vtx.y, vtx.z);
		objFile.writefln("vt %f %f", vtx.u, vtx.v);
	}

	override void createFace(size_t v1CacheIdx, size_t v2CacheIdx, size_t v3CacheIdx)
	{
		size_t v1 = vertexCacheToObjVertex[v1CacheIdx];
		size_t v2 = vertexCacheToObjVertex[v2CacheIdx];
		size_t v3 = vertexCacheToObjVertex[v3CacheIdx];

		objFile.writefln("f %d/%d %d/%d %d/%d", v1, v1, v2, v2, v3, v3);
	}

	override void selectTexture(Texture tex)
	{
		if (tex !in textureCache)
		{
			string texName = format("%d.%s", currentMaterial, tex.exportExtension());
			string mtlName = format("mat%d", currentMaterial);

			// Save the texture
			string texPath = buildPath(outputDirectory, texName);

			Stream s = new std.stream.BufferedFile(texPath, FileMode.OutNew);
			scope(exit) s.close();
			tex.exportTo(s);

			// Define new material for texture
			mtlFile.writefln("newmtl %s", mtlName);
			mtlFile.writefln("map_Kd %s", texName);
			mtlFile.writefln();
			
			// Add the material to the cache
			textureCache[tex] = mtlName;

			currentMaterial++;
		}
		
		objFile.writefln("usemtl %s", textureCache[tex]);
	}
}

/+
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.sdl.sdl;

import std.stdio;
import std.math;

// http://www.opengl.org/resources/faq/technical/viewing.htm
class ModelViewer : ModelExporter
{
	/// Vertex cache (only used during loading).
	ModelVertex[16] vertexCache;
	/// Commands to execute to render the model.
	GlCommand[] renderCommands;

	double cameraX = 0.0, cameraY = 0.0, cameraZ = 10000.0;
	double centerX = 0.0, centerY = 0.0, centerZ = 0.0;
	double rotationX = 0.0, rotationY = 0.0;

	double sceneRadius = 0.0;

	/// Base class for all OpenGL rendering command classes.
	private class GlCommand
	{
		abstract void execute();
	}

	/// OpenGL triangle command.
	private class GlTriangleCommand : GlCommand
	{
		ModelVertex[3] vtx;

		this(ModelVertex[3] vtx)
		{
			this.vtx = vtx;
		}

		void execute()
		{
			glBegin(GL_TRIANGLES);
			foreach (v; vtx)
			{
				glTexCoord2d(v.u, v.v);
				glVertex3d(v.x, v.y, v.z);
			}
			glEnd();
		}
	}

	/// OpenGL texture command.
	private class GlTextureCommand : GlCommand
	{
		Texture tex;
		GLuint id;

		this(Texture tex)
		{
			this.tex = tex;
			glGenTextures(1, &id);
			glBindTexture(GL_TEXTURE_2D, id);
			glTexImage2D(GL_TEXTURE_2D, 0, 4, tex.width, tex.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, tex.pixelData);
			glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);	// Linear Filtering
			glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);	// Linear Filtering
		}

		~this()
		{
			glDeleteTextures(1, &id);
		}

		void execute()
		{
			glBindTexture(GL_TEXTURE_2D, id);
		}
	}

	/// Create a ModelViewer
	this()
	{
		// Set up our rendering window
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		SDL_SetVideoMode(640, 480, 32, SDL_OPENGL);
		SDL_WM_SetCaption(toStringz("M64ModelView"), null);

		// Set the default background color (black)
		glClearColor(0.0f, 0.0f, 0.0f, 0.0f);

		// Enable depth
		glEnable(GL_DEPTH_TEST);

		// Enable texturing
		glEnable(GL_TEXTURE_2D);

		// Enable blending to get the alpha channel of the textures working
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		reconfigureView();
	}

	private void reconfigureView()
	{
		// Set up the projection matrix
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		gluPerspective(40.0, 1.0, 1.0, cameraZ + sceneRadius); // TODO set aspectratio

		// Set up the view matrix
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		gluLookAt(
			cameraX, cameraY, cameraZ,
			centerX, centerY, centerZ,
			0.0, 1.0, 0.0);

		glRotatef(rotationX, 0.0f, 1.0f, 0.0f);
		glRotatef(rotationY, 1.0f, 0.0f, 0.0f);
	}

	void createObject(string name)
	{
	}

	void writeComment(string comment)
	{
	}

	void addVertexToCache(size_t cacheIdx, ModelVertex vtx)
	{
		vertexCache[cacheIdx] = vtx;

		double dist = sqrt(vtx.x * vtx.x + vtx.y * vtx.y + vtx.z * vtx.z);
		if (dist > sceneRadius)
			sceneRadius = dist;
	}

	void createFace(size_t v1CacheIdx, size_t v2CacheIdx, size_t v3CacheIdx)
	{
		ModelVertex[3] tri;
		tri[0] = vertexCache[v1CacheIdx];
		tri[1] = vertexCache[v2CacheIdx];
		tri[2] = vertexCache[v3CacheIdx];

		renderCommands ~= new GlTriangleCommand(tri);
	}

	void selectTexture(Texture tex)
	{
		renderCommands ~= new GlTextureCommand(tex);
	}

	/// Start the rendering loop.
	void display()
	{
		bool cameraMode = false;
		while (true)
		{
			SDL_Event event;
			while (SDL_PollEvent(&event))
			{
				switch (event.type)
				{
					case SDL_MOUSEBUTTONDOWN:
						if (event.button.button == SDL_BUTTON_LEFT)
						{
							// Start camera rotation mode
							cameraMode = true;
							SDL_ShowCursor(0);
						}
						else if (event.button.button == SDL_BUTTON_WHEELDOWN)
						{
							cameraZ = cameraZ * 9.0 / 10.0;
							reconfigureView();
						}
						else if (event.button.button == SDL_BUTTON_WHEELUP)
						{
							cameraZ = cameraZ * 10.0 / 9.0;
							reconfigureView();						
						}
						break;

					case SDL_MOUSEBUTTONUP:
						if (event.button.button == SDL_BUTTON_LEFT)
						{
							// End camera rotation mode
							cameraMode = false;
							SDL_ShowCursor(1);
						}
						break;

					case SDL_MOUSEMOTION:
						if (cameraMode == true)
						{
							rotationX += cast(double)event.motion.xrel / 10.0;
							rotationY += cast(double)event.motion.yrel / 10.0;
							reconfigureView();
						}
						break;

					case SDL_QUIT:
						return;

					default:
						break;
				}
			}

			render();
		}
	}

	/// Render the model to the window.
	private void render()
	{
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		foreach (cmd; renderCommands)
			cmd.execute();

		SDL_GL_SwapBuffers();
	}
}
+/
