using OpenGL;
using Uno.Runtime.Implementation.ShaderBackends.OpenGL;
using Uno.Compiler.ExportTargetInterop;
using Uno.Graphics.Support;
using Uno.IO;

namespace Uno.Graphics
{
    public sealed intrinsic class TextureCube : IDisposable
    {
        public static TextureCube Load(BundleFile file)
        {
            if defined(JAVASCRIPT)
                return JsTexture.LoadCube(file.BundlePath);
            else
                return Load(file.Name, file.ReadAllBytes());
        }

        public static TextureCube Load(string filename)
        {
            return Load(filename, File.ReadAllBytes(filename));
        }

        public static TextureCube Load(string filename, byte[] bytes)
        {
            if defined(CPLUSPLUS)
                return CppTexture.LoadCube(filename, bytes);
            else if defined(DOTNET)
                return DotNetTexture.LoadCube(filename, bytes);
            else
                throw new NotImplementedException();
        }

        public int Size
        {
            get;
            private set;
        }

        public int MipCount
        {
            get;
            private set;
        }

        public Format Format
        {
            get;
            private set;
        }

        public extern(OPENGL) GLTextureHandle GLTextureHandle
        {
            get;
            private set;
        }

        public extern(OPENGL) TextureCube(GLTextureHandle handle, int size, int mipCount, Format format)
        {
            GLTextureHandle = handle;

            Size = size;
            MipCount = mipCount;
            Format = format;
        }

        public TextureCube(int size, Format format, bool mipmap)
        {
            if defined(OPENGL)
                GLTextureHandle = GL.CreateTexture();
            else
                build_error;

            Size = size;
            Format = format;
            MipCount = mipmap ? TextureHelpers.GetMipCount(size) : 1;

            for (int i = 0; i < 6; i++)
                Update((CubeFace)i, (byte[])null);
        }

        public bool IsDisposed
        {
            get;
            private set;
        }

        public void Dispose()
        {
            if (IsDisposed)
                throw new ObjectDisposedException("TextureCube");
            else if defined(OPENGL)
                GL.DeleteTexture(GLTextureHandle);
            else
                build_error;

            IsDisposed = true;
        }

        public bool CanUpdate
        {
            get { return Format != Format.Unknown; }
        }

        public void Update(CubeFace face, byte[] mip0)
        {
            if (Format == Format.Unknown)
            {
                throw new InvalidOperationException("Texture is immutable and cannot be updated");
            }
            else if defined(OPENGL)
            {
                GL.ActiveTexture(GLTextureUnit.Texture0);
                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.MagFilter, GLTextureParameterValue.Linear);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.MinFilter, GLTextureParameterValue.Linear);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.WrapS, GLTextureParameterValue.ClampToEdge);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.WrapT, GLTextureParameterValue.ClampToEdge);
                GLHelpers.TexImage2DFromBytes((GLTextureTarget)((int)GLTextureTarget.TextureCubeMapPositiveX + (int)face), Size, Size, 0, Format, mip0);
                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle.Zero);
            }
            else
            {
                build_error;
            }
        }

        [Obsolete("Use the byte[] overload instead")]
        public void Update(CubeFace face, Buffer mip0)
        {
            if (Format == Format.Unknown)
            {
                throw new InvalidOperationException("Texture is immutable and cannot be updated");
            }
            else if defined(OPENGL)
            {
                GL.ActiveTexture(GLTextureUnit.Texture0);
                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.MagFilter, GLTextureParameterValue.Linear);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.MinFilter, GLTextureParameterValue.Linear);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.WrapS, GLTextureParameterValue.ClampToEdge);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.WrapT, GLTextureParameterValue.ClampToEdge);
                GLHelpers.TexImage2DFromBuffer((GLTextureTarget)((int)GLTextureTarget.TextureCubeMapPositiveX + (int)face), Size, Size, 0, Format, mip0);
                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle.Zero);
            }
            else
            {
                build_error;
            }
        }

        public void Update(CubeFace face, int firstMip, params byte[][] mips)
        {
            if (Format == Format.Unknown)
            {
                throw new InvalidOperationException("Texture is immutable and cannot be updated");
            }
            else if defined(OPENGL)
            {
                GL.ActiveTexture(GLTextureUnit.Texture0);
                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.MagFilter, GLTextureParameterValue.Linear);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.MinFilter, GLTextureParameterValue.Linear);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.WrapS, GLTextureParameterValue.ClampToEdge);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.WrapT, GLTextureParameterValue.ClampToEdge);

                int wh = Size;

                for (int i = 0; i < MipCount; i++)
                {
                    if (i >= firstMip)
                        GLHelpers.TexImage2DFromBytes((GLTextureTarget)((int)GLTextureTarget.TextureCubeMapPositiveX + (int)face), wh, wh, i, Format, mips[i]);

                    wh = wh >> 1;

                    if (wh < 1)
                        wh = 1;

                    if (i >= mips.Length - firstMip)
                        break;
                }

                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle.Zero);
            }
            else
            {
                build_error;
            }
        }

        [Obsolete("Use the byte[] overload instead")]
        public void Update(CubeFace face, int firstMip, params Buffer[] mips)
        {
            if (Format == Format.Unknown)
            {
                throw new InvalidOperationException("Texture is immutable and cannot be updated");
            }
            else if defined(OPENGL)
            {
                GL.ActiveTexture(GLTextureUnit.Texture0);
                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.MagFilter, GLTextureParameterValue.Linear);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.MinFilter, GLTextureParameterValue.Linear);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.WrapS, GLTextureParameterValue.ClampToEdge);
                GL.TexParameter(GLTextureTarget.TextureCubeMap, GLTextureParameterName.WrapT, GLTextureParameterValue.ClampToEdge);

                int wh = Size;

                for (int i = 0; i < MipCount; i++)
                {
                    if (i >= firstMip)
                        GLHelpers.TexImage2DFromBuffer((GLTextureTarget)((int)GLTextureTarget.TextureCubeMapPositiveX + (int)face), wh, wh, i, Format, mips[i]);

                    wh = wh >> 1;

                    if (wh < 1)
                        wh = 1;

                    if (i >= mips.Length - firstMip)
                        break;
                }

                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle.Zero);
            }
            else
            {
                build_error;
            }
        }

        public bool IsPow2
        {
            get { return Math.IsPow2(Size); }
        }

        public bool IsMipmap
        {
            get { return MipCount > 1 && IsPow2; }
        }

        [Obsolete("Use 'IsMipmap' instead")]
        public bool SupportsMipmap
        {
            get { return IsMipmap; }
        }

        public void GenerateMipmap()
        {
            if (!IsMipmap)
            {
                throw new InvalidOperationException("Texture does not support mipmap");
            }
            else if defined(OPENGL)
            {
                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle);
                GL.GenerateMipmap(GLTextureTarget.TextureCubeMap);
                GL.BindTexture(GLTextureTarget.TextureCubeMap, GLTextureHandle.Zero);
            }
            else
            {
                build_error;
            }
        }
    }
}
