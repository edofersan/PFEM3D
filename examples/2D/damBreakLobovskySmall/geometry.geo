//+
L = 1.610;
//+
H = 0.300;
//+
D = 0.600;
//+
B = 0.600;
//+
d = L/10;
//+
Point(1) = {0, 0, 0, d};
//+
Point(2) = {L, 0, 0, d};
//+
Point(3) = {L, D, 0, d};
//+
Point(4) = {0, D, 0, d};
//+
Point(5) = {L-B, H, 0, d};
//+
Point(6) = {L, H, 0, d};
//+
Point(7) = {L-B, 0, 0, d};
//+
Line(1) = {2, 6};
//+
Line(2) = {6, 5};
//+
Line(3) = {5, 7};
//+
Line(4) = {2, 7};
//+
Line(5) = {6, 3};
//+
Line(6) = {4, 1};
//+
Line(7) = {1, 7};
//+
Curve Loop(1) = {4, -3, -2, -1};
//+
Surface(1) = {1};
//+
Physical Curve("Boundary") = {6, 7, 4, 1, 5};
//+
Physical Curve("FreeSurface") = {2,3};
//+
Physical Surface("Fluid") = {1};
//+
Transfinite Surface{1};
