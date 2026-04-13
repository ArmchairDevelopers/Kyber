namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(MeshScatteringTree, 0x1445436D0);
_KB_DECLARE_TYPEINFO(DisplacementTextureTree, 0x144543750);
_KB_DECLARE_TYPEINFO(VisualTerrainSettings, 0x1445434E0);
_KB_DECLARE_TYPEINFO(TerrainRenderMode, 0x1445434A0);
_KB_DECLARE_TYPEINFO(VisualTerrain, 0x144543200);
_KB_DECLARE_TYPEINFO(TerrainLayerCombinations, 0x144543100);
_KB_DECLARE_TYPEINFO(TerrainDecals, 0x144543180);
_KB_DECLARE_TYPEINFO(IVisualTerrain, 0x144543280);
_KB_DECLARE_TYPEINFO(TerrainTextureTree, 0x144543300);

#undef _KB_DECLARE_TYPEINFO
}
