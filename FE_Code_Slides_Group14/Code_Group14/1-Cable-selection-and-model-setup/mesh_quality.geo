// [Section 1] Size and quality of a mesh: number of triangles and Gmsh's ICN quality
// (inverse condition number; 1 = equilateral triangle, 0 = degenerate). From this folder:
//   gmsh meshes/gap.msh mesh_quality.geo -nopopup -parse_and_exit
// prints "Triangles: ..." and "ICN = worst, average, best".
Printf("Triangles: %g", Mesh.NbTriangles);
Plugin(AnalyseMeshQuality).JacobianDeterminant = 0;
Plugin(AnalyseMeshQuality).IGEMeasure = 0;
Plugin(AnalyseMeshQuality).ICNMeasure = 1;
Plugin(AnalyseMeshQuality).DimensionOfElements = 2;
Plugin(AnalyseMeshQuality).CreateView = 0;
Plugin(AnalyseMeshQuality).Run;
