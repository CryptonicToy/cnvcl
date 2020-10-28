{******************************************************************************}
{                       CnPack For Delphi/C++Builder                           }
{                     中国人自己的开放源码第三方开发包                         }
{                   (C)Copyright 2001-2020 CnPack 开发组                       }
{                   ------------------------------------                       }
{                                                                              }
{            本开发包是开源的自由软件，您可以遵照 CnPack 的发布协议来修        }
{        改和重新发布这一程序。                                                }
{                                                                              }
{            发布这一开发包的目的是希望它有用，但没有任何担保。甚至没有        }
{        适合特定目的而隐含的担保。更详细的情况请参阅 CnPack 发布协议。        }
{                                                                              }
{            您应该已经和开发包一起收到一份 CnPack 发布协议的副本。如果        }
{        还没有，可访问我们的网站：                                            }
{                                                                              }
{            网站地址：http://www.cnpack.org                                   }
{            电子邮件：master@cnpack.org                                       }
{                                                                              }
{******************************************************************************}

unit CnECC;
{* |<PRE>
================================================================================
* 软件名称：开发包基础库
* 单元名称：椭圆曲线算法单元
* 单元作者：刘啸
* 备    注：目前实现了 Int64 范围内以及大数形式的形如 y^2 = x^3 + Ax + B mod p
*           这类椭圆曲线的计算，x 和 y 限于有限素域。
* 开发平台：WinXP + Delphi 5.0
* 兼容测试：暂未进行
* 本 地 化：该单元无需本地化处理
* 修改记录：2020.10.25 V1.6
*               实现 Int64 范围内的基础 Schoof 算法并初步测试通过
*           2020.04.06 V1.5
*               实现 ECC 签名验签，类似于 openssl 的功能
*               openssl dgst -sha256 -sign ec.pem -out hello.sig hello
*               openssl dgst -sha256 -verify ecpub.pem -signature hello.sig hello
*               注意 Ecc 的签名只针对消息 Hash，输出中不带 Hash 算法种类与用户信息，
*               与 SM2 规范不同，与 RSA 的 Hash 后补 Hash 种类再对齐成 BER 内容也不同
*           2020.03.28 V1.4
*               实现 ECC 公私钥 PEM 文件的生成与读写，类似于 openssl 的功能
*               openssl ecparam -name secp256k1 -genkey -out ec.pem
*               openssl ec -in ec.pem -pubout -out ecpub.pem
*           2018.09.29 V1.3
*               实现大数椭圆曲线根据 X 求 Y 的两种算法，并默认用速度更快的 Lucas
*           2018.09.13 V1.2
*               初步实现大数椭圆曲线的加解密功能，支持 SM2 以及 Secp256k1 等曲线
*           2018.09.10 V1.1
*               能够生成系数很小的椭圆曲线参数
*           2018.09.05 V1.0
*               创建单元
================================================================================
|</PRE>}

interface

{$I CnPack.inc}

{$DEFINE USE_LUCAS}
// 定义此条件，求点也就是根据 X 计算椭圆曲线方程的 Y 值时使用 Lucas 序列算法来计算
// 如不定义，则使用 Tonelli-Shanks 算法计算。Tonelli-Shanks 速度较慢，大数范围内
// 比起 Lucas 序列慢 10 倍以上。

uses
  SysUtils, Classes, Contnrs, Windows, CnNativeDecl, CnPrimeNumber, CnBigNumber,
  CnPolynomial, CnPemUtils, CnBerUtils, CnMD5, CnSHA1, CnSHA2, CnSM3;

const
  // ecPublicKey 的 OID
  OID_EC_PUBLIC_KEY: array [0..6] of Byte = (               // 1.2.840.10045.2.1
    $2A, $86, $48, $CE, $3D, $02, $01
  );

type
  TCnEccSignDigestType = (esdtMD5, esdtSHA1, esdtSHA256, esdtSM3);
  {* ECC 签名所支持的数字摘要算法，不支持无摘要的方式}

  ECnEccException = class(Exception);

  TCnEccPrimeType = (pt4U3, pt8U5, pt8U1);
  {* 素数类型，mod 4 余 3、mod 8 余 5、mod 8 余 1，用于椭圆曲线方程中快速求 Y}

  TCnInt64EccPoint = packed record
  {* Int64 范围内的椭圆曲线上的点描述结构}
    X: Int64;
    Y: Int64;
  end;

  TCnInt64PublicKey = TCnInt64EccPoint;
  {* Int64 范围内的椭圆曲线的公钥，G 点计算 k 次后的点坐标}

  TCnInt64PrivateKey = Int64;
  {* Int64 范围内的椭圆曲线的私钥，计算次数 k 次}

  TCnInt64Ecc = class
  {* 描述一有限素域 p 也就是 0 到 p - 1 上的椭圆曲线 y^2 = x^3 + Ax + B mod p，参数均在 Int64 范围内}
  private
    FGenerator: TCnInt64EccPoint;
    FCoefficientA: Int64;
    FCoefficientB: Int64;
    FFiniteFieldSize: Int64;
    FOrder: Int64;
    FSizeUFactor: Int64;
    FSizePrimeType: TCnEccPrimeType;
  protected
    // Tonelli-Shanks 模素数二次剩余求解，返回 False 表示失败，调用者需自行保证 P 为素数
    function TonelliShanks(X, P: Int64; out Y: Int64): Boolean;
    // Lucas 序列模素数二次剩余求解，返回 False 表示失败，只针对 P 为 8*u + 1 的形式
    function Lucas(X, P: Int64; out Y: Int64): Boolean;
  public
    constructor Create(A, B, FieldPrime, GX, GY, Order: Int64);
    {* 构造函数，传入方程的 A, B 参数、有限域上界 p、G 点坐标、G 点的阶数}
    destructor Destroy; override;
    {* 析构函数}

    procedure MultiplePoint(K: Int64; var Point: TCnInt64EccPoint);
    {* 计算某点 P 的 k * P 值，值重新放入 P}
    procedure PointAddPoint(var P, Q, Sum: TCnInt64EccPoint);
    {* 计算 P + Q，值放入 Sum 中，Sum 可以是 P、Q 之一，P、Q 可以相同}
    procedure PointSubPoint(var P, Q, Diff: TCnInt64EccPoint);
    {* 计算 P - Q，值放入 Diff 中，Diff 可以是 P、Q 之一，P、Q 可以相同}
    procedure PointInverse(var P: TCnInt64EccPoint);
    {* 计算 P 点的逆元 -P，值重新放入 P}
    function IsPointOnCurve(var P: TCnInt64EccPoint): Boolean;
    {* 判断 P 点是否在本曲线上}

    function DivisionPolynomial(Degree: Integer; outDivisionPolynomial: TCnInt64Polynomial): Boolean;
    {* 递归计算第 Degree 个可除多项式，返回计算是否成功}

    function PlainToPoint(Plain: Int64; var OutPoint: TCnInt64EccPoint): Boolean;
    {* 将要加密的明文数值包装成一个待加密的点，也就是以明文为 X 求方程的 Y
       注意 Plain 为 0 时直接对应至零点，即使椭圆曲线上有 (0, 非零 Y)形式的合法点存在}

    procedure GenerateKeys(out PrivateKey: TCnInt64PrivateKey; out PublicKey: TCnInt64PublicKey);
    {* 生成一对该椭圆曲线的公私钥，私钥是运算次数 k，公钥是基点 G 经过 k 次乘法后得到的点坐标 K}
    procedure Encrypt(var PlainPoint: TCnInt64EccPoint; PublicKey: TCnInt64PublicKey;
      var OutDataPoint1, OutDataPoint2: TCnInt64EccPoint; RandomKey: Int64 = 0);
    {* 公钥加密明文点 M，得到两个点的输出密文，内部包含了随机值 r，也就是 C1 = M + rK; C2 = r * G
      如果传入的 RandomKey 是 0，则内部随机生成}
    procedure Decrypt(var DataPoint1, DataPoint2: TCnInt64EccPoint;
      PrivateKey: TCnInt64PrivateKey; var OutPlainPoint: TCnInt64EccPoint);
    {* 私钥解密密文点，也就是计算 C1 - k * C2 就得到了原文点 M}

    property Generator: TCnInt64EccPoint read FGenerator;
    {* 基点坐标 G}
    property CoefficientA: Int64 read FCoefficientA;
    {* 方程系数 A}
    property CoefficientB: Int64 read FCoefficientB;
    {* 方程系数 B}
    property FiniteFieldSize: Int64 read FFiniteFieldSize;
    {* 有限域的上界，素数 p}
    property Order: Int64 read FOrder;
    {* 基点的阶数}
  end;

  TCnEccPoint = class(TPersistent)
  {* 有限素域上的椭圆曲线上的点描述类}
  private
    FY: TCnBigNumber;
    FX: TCnBigNumber;
    procedure SetX(const Value: TCnBigNumber);
    procedure SetY(const Value: TCnBigNumber);
  public
    constructor Create; overload;
    constructor Create(const XDec, YDec: AnsiString); overload;

    destructor Destroy; override;

    procedure Assign(Source: TPersistent); override;
    function IsZero: Boolean;
    procedure SetZero;

    property X: TCnBigNumber read FX write SetX;
    property Y: TCnBigNumber read FY write SetY;
  end;

  TCnEccPublicKey = TCnEccPoint;
  {* 椭圆曲线的公钥，G 点计算 k 次后的点坐标}

  TCnEccPrivateKey = TCnBigNumber;
  {* 椭圆曲线的私钥，计算次数 k 次}

  TCnEccCurveType = (ctCustomized, ctSM2, ctSM2Example192, ctSM2Example256,
    ctRfc4754ECDSAExample256, ctSecp224r1, ctSecp224k1, ctSecp256k1, ctPrime256v1);
  {* 支持的椭圆曲线类型}

  TCnEcc = class
  {* 描述一有限素域 p 也就是 0 到 p - 1 上的椭圆曲线 y^2 = x^3 + Ax + B mod p}
  private
    FCoefficientB: TCnBigNumber;
    FCoefficientA: TCnBigNumber;
    FOrder: TCnBigNumber;
    FFiniteFieldSize: TCnBigNumber;
    FGenerator: TCnEccPoint;
    FSizeUFactor: TCnBigNumber;
    FSizePrimeType: TCnEccPrimeType;
    FCoFactor: Integer;
    function GetBitsCount: Integer;
  protected
    procedure CalcX3AddAXAddB(X: TCnBigNumber); // 计算 X^3 + A*X + B，结果放入 X
  public
    constructor Create; overload; virtual;
    constructor Create(Predefined: TCnEccCurveType); overload;
    constructor Create(const A, B, FieldPrime, GX, GY, Order: AnsiString; H: Integer = 1); overload;
    {* 构造函数，传入方程的 A, B 参数、有限域上界 p、G 点坐标、G 点的阶数，需要十六进制字符串}
    destructor Destroy; override;
    {* 析构函数}

    procedure Load(Predefined: TCnEccCurveType); overload; virtual;
    procedure Load(const A, B, FieldPrime, GX, GY, Order: AnsiString; H: Integer = 1); overload; virtual;
    {* 加载曲线参数，注意字符串参数是十六进制格式}

    procedure MultiplePoint(K: TCnBigNumber; Point: TCnEccPoint);
    {* 计算某点 P 的 k * P 值，值重新放入 P}
    procedure PointAddPoint(P, Q, Sum: TCnEccPoint);
    {* 计算 P + Q，值放入 Sum 中，Sum 可以是 P、Q 之一，P、Q 可以相同}
    procedure PointSubPoint(P, Q, Diff: TCnEccPoint);
    {* 计算 P - Q，值放入 Diff 中，Diff 可以是 P、Q 之一，P、Q 可以相同}
    procedure PointInverse(P: TCnEccPoint);
    {* 计算 P 点的逆元 -P，值重新放入 P}
    function IsPointOnCurve(P: TCnEccPoint): Boolean;
    {* 判断 P 点是否在本曲线上}

    function PlainToPoint(Plain: TCnBigNumber; OutPoint: TCnEccPoint): Boolean;
    {* 将要加密的明文数值包装成一个待加密的点，也就是以明文为 X 求方程的 Y
       注意 Plain 为 0 时直接对应至零点，即使椭圆曲线上有 (0, 非零 Y)形式的合法点存在}
    function PointToPlain(Point: TCnEccPoint; OutPlain: TCnBigNumber): Boolean;
    {* 将解密出的明文点解开成一个明文数值，也就是将点的 X 值取出}

    procedure GenerateKeys(PrivateKey: TCnEccPrivateKey; PublicKey: TCnEccPublicKey);
    {* 生成一对该椭圆曲线的公私钥，私钥是运算次数 k，公钥是基点 G 经过 k 次乘法后得到的点坐标 K}
    procedure Encrypt(PlainPoint: TCnEccPoint; PublicKey: TCnEccPublicKey;
      OutDataPoint1, OutDataPoint2: TCnEccPoint);
    {* 公钥加密明文点 M，得到两个点的输出密文，内部包含了随机值 r，也就是 C1 = M + rK; C2 = r * G}
    procedure Decrypt(DataPoint1, DataPoint2: TCnEccPoint;
      PrivateKey: TCnEccPrivateKey; OutPlainPoint: TCnEccPoint);
    {* 私钥解密密文点，也就是计算 C1 - k * C2 就得到了原文点 M}

    property Generator: TCnEccPoint read FGenerator;
    {* 基点坐标 G}
    property CoefficientA: TCnBigNumber read FCoefficientA;
    {* 方程系数 A}
    property CoefficientB: TCnBigNumber read FCoefficientB;
    {* 方程系数 B}
    property FiniteFieldSize: TCnBigNumber read FFiniteFieldSize;
    {* 有限域的上界，素数 p}
    property Order: TCnBigNumber read FOrder;
    {* 基点的阶数 N}
    property CoFactor: Integer read FCoFactor;
    {* 辅助因子 H，也就是总点数 mod N，先用 Integer 表示，一般都是 1}
    property BitsCount: Integer read GetBitsCount;
    {* 该椭圆曲线的素数域位数}
  end;

  TCnEccKeyType = (cktPKCS1, cktPKCS8);
  {* ECC 密钥文件格式}

  TCnInt64PolynomialEccPoint = class(TPersistent)
  {* 有限扩域上的椭圆曲线上的多项式点描述类}
  private
    FY: TCnInt64Polynomial;
    FX: TCnInt64Polynomial;
    procedure SetX(const Value: TCnInt64Polynomial);
    procedure SetY(const Value: TCnInt64Polynomial);
  public
    constructor Create; overload;
    constructor Create(const XLowToHighCoefficients, YLowToHighCoefficients: array of const); overload;

    destructor Destroy; override;

    procedure Assign(Source: TPersistent); override;
    function IsZero: Boolean;
    procedure SetZero;

    function ToString: string; {$IFDEF OBJECT_HAS_TOSTRING} override; {$ENDIF}
    {* 将多项式转成字符串}

    property X: TCnInt64Polynomial read FX write SetX;
    property Y: TCnInt64Polynomial read FY write SetY;
  end;
  
  TCnInt64PolynomialEcc = class
  {* 描述一有限扩域 p 也就是 0 到 p - 1 上 n 次方内的椭圆曲线 y^2 = x^3 + Ax + B mod p，参数均在 Int64 范围内}
  private
    FGenerator: TCnInt64PolynomialEccPoint;
    FCoefficientA: Int64;
    FCoefficientB: Int64;
    FFiniteFieldSize: Int64;
    FOrder: Int64;
    FExtension: Integer;
    FPrimitive: TCnInt64Polynomial;
    procedure SetPrimitive(const Value: TCnInt64Polynomial);
//    class procedure MultiplePoint1(K: Integer; PX, PY: TCnInt64Polynomial;
//      A, B, APrime: Int64; APrimitive: TCnInt64Polynomial);
  protected

  public
    constructor Create(A, B, FieldPrime: Int64; Ext: Integer; GX, GY: array of const;
      Order: Int64; PrimitivePolynomial: array of const);
    {* 构造函数，传入方程的 A, B 参数、有限域上界 p、扩域次数，G 点坐标多项式、G 点的阶数、本原多项式}
    destructor Destroy; override;
    {* 析构函数}

    procedure MultiplePoint(K: Integer; Point: TCnInt64PolynomialEccPoint);
    {* 计算某点 P 的 k * P 值，值重新放入 P}
    procedure PointAddPoint(P, Q, Sum: TCnInt64PolynomialEccPoint);
    {* 计算 P + Q，值放入 Sum 中，Sum 可以是 P、Q 之一，P、Q 可以相同}
    procedure PointSubPoint(P, Q, Diff: TCnInt64PolynomialEccPoint);
    {* 计算 P - Q，值放入 Diff 中，Diff 可以是 P、Q 之一，P、Q 可以相同}
    procedure PointInverse(P: TCnInt64PolynomialEccPoint);
    {* 计算 P 点的逆元 -P，值重新放入 P}
    function IsPointOnCurve(P: TCnInt64PolynomialEccPoint): Boolean;
    {* 判断 P 点是否在本曲线上}

    function DivisionPolynomial(Degree: Integer; outDivisionPolynomial: TCnInt64Polynomial): Boolean;
    {* 递归计算第 Degree 个可除多项式，返回计算是否成功，注意次数一多就容易慢}

    class function IsPointOnCurve2(PX, PY: TCnInt64Polynomial; A, B, APrime: Int64;
      APrimitive: TCnInt64Polynomial): Boolean;
    {* 供外界直接调用的判断（PX, PY）点是否在本曲线上，
       椭圆曲线参数直接指定 A、B、素域上界与本原多项式，无需基点和阶以及扩域次数}

//    class procedure PointAddPoint1(PX, PY, QX, QY, SX, SY: TCnInt64Polynomial; A, B, APrime: Int64;
//      APrimitive: TCnInt64Polynomial);
//    {* 供外界直接调用的点加方法，将点（PX, PY * y) 和点（QX, QY * y）相加，结果放到（SX, SY * y）点中
//       椭圆曲线参数直接指定 A、B、素域上界与本原多项式，无需基点和阶以及扩域次数，SX/SY 不可以是 PX/PY/QX/QY}
//
//    class procedure PointAddPoint2(PX, PY, QX, QY, SX, SY: TCnInt64Polynomial; A, B, APrime: Int64;
//      APrimitive: TCnInt64Polynomial);
//    {* 供外界直接调用的点加方法，将点（PX, PY) 和点（QX, QY）相加，结果放到（SX, SY）点中，暂时用不上
//       椭圆曲线参数直接指定 A、B、素域上界与本原多项式，无需基点和阶以及扩域次数}

    class procedure RationalPointAddPoint(PX, PY, QX, QY: TCnInt64RationalPolynomial;
      SX, SY: TCnInt64RationalPolynomial; A, B, APrime: Int64; APrimitive: TCnInt64Polynomial = nil);
    {* 供外界直接调用的点加方法，将点（PX, PY * y) 和点（QX, QY * y）相加，结果放到（SX, SY * y）点中
       注意本方法中并不把除法转换为乘法，所有内容包括斜率等内容需要用分式表示，结果也以分式形式输出
       PX、PY、QX、QY、SX、SY均为分子分母为纯 x 多项式的分式，SX、SY 不能是 PX、PY、QX、QY
       另外该方法一般不用于计算后代入具体数值求值，因为计算时无法直接判断值是否相等导致斜率计算与实际值有偏差
       Schoof 算法中，本原多项式为指定阶数的可除多项式，以构造多项式环来降低运算次数，初步验证通过}

    class procedure RationalMultiplePoint(K: Integer; MX, MY: TCnInt64RationalPolynomial;
      A, B, APrime: Int64; APrimitive: TCnInt64Polynomial = nil);
    {* 供外界直接调用的多倍点方法，使用可除多项式直接计算点（x, 1 * y) 的 k * P 值，值放入 MX, MY * y
       注意本方法中并不把除法转换为乘法，所有内容包括斜率等内容需要用分式表示，结果也以分式形式输出
       PX、PY、QX、QY、SX、SY均为分子分母为纯 x 多项式的分式，，SX、SY 不能是 PX、PY、QX、QY
       另外该方法一般不用于计算后代入具体数值求值，因为计算时无法直接判断值是否相等导致斜率计算与实际值有偏差
       Schoof 算法中，本原多项式为指定阶数的可除多项式，以构造多项式环来降低运算次数}

    class function IsRationalPointOnCurve(PX, PY: TCnInt64RationalPolynomial;
      A, B, APrime: Int64): Boolean;
    {* 供外界直接调用的无本原多项式的判断（PX, PY * y）点是否在本曲线上，基本上没有被调用的场合
       椭圆曲线参数直接指定 A、B、素域上界与，无需本原多项式、基点和阶以及扩域次数
       注意在无本原多项式的情况下，除法无法转换为乘法，所有内容包括斜率等内容需要用分式表示}

    property Generator: TCnInt64PolynomialEccPoint read FGenerator;
    {* 基点坐标 G}
    property CoefficientA: Int64 read FCoefficientA;
    {* 方程系数 A}
    property CoefficientB: Int64 read FCoefficientB;
    {* 方程系数 B}
    property FiniteFieldSize: Int64 read FFiniteFieldSize;
    {* 有限素域的上界，素数 p}
    property Extension: Integer read FExtension write FExtension;
    {* 有限扩域的次数，也即素数 p 的指数}
    property Order: Int64 read FOrder;
    {* 基点的阶数}
    property Primitive: TCnInt64Polynomial read FPrimitive write SetPrimitive;
    {* 本原多项式}
  end;

function CnInt64EccPointToString(var P: TCnInt64EccPoint): string;
{* 将一个 TCnInt64EccPoint 点坐标转换为字符串}

function CnInt64EccSchoof(A, B, Q: Int64): Int64;
{* 用 Schoof 算法求椭圆曲线 y^2 = x^3 + Ax + B 在素域 Fq 上的点总数，
   Q 最大支持 Sqrt(2 * Max UInt64)，略大于 Max UInt32
   Schoof 算法有两个版本，思想一样，但运算过程不同，
   一个是利用点的多项分式在素数域以及基于可除多项式环上进行完整循环运算，比较慢
   一个是判断时多用各种分子的最大公因式以减少数据量}

function CnEccPointToString(const P: TCnEccPoint): string;
{* 将一个 TCnEccPoint 点坐标转换为十进制字符串}

function CnEccPointToHex(const P: TCnEccPoint): string;
{* 将一个 TCnEccPoint 点坐标转换为十六进制字符串}

function CnInt64EccGenerateParams(var FiniteFieldSize, CoefficientA, CoefficientB,
  GX, GY, Order: Int64): Boolean;
{* 生成椭圆曲线 y^2 = x^3 + Ax + B mod p 的各个参数，难以完整实现，只能先生成系数很小的}

function CnInt64EccDiffieHellmanGenerateOutKey(Ecc: TCnInt64Ecc; SelfPrivateKey: TCnInt64PrivateKey;
  out PublicKey: TCnInt64PublicKey): Boolean;
{* 根据自身选择的随机数 PrivateKey 生成 ECDH 密钥协商的输出公钥点
   其中 OutPublicKey = SelfPrivateKey * G}

function CnInt64EccDiffieHellmanComputeKey(Ecc: TCnInt64Ecc; SelfPrivateKey: TCnInt64PrivateKey;
  var OtherPublicKey: TCnInt64PublicKey; var SharedSecretKey: TCnInt64PublicKey): Boolean;
{* 根据对方发送的 ECDH 密钥协商的输出公钥计算生成公认的密钥点
   其中 SecretKey = SelfPrivateKey * OtherPublicKey}

function CnInt64EccPointsEqual(var P1, P2: TCnInt64EccPoint): Boolean;
{* 判断两个 TCnInt64EccPoint 点是否相等}

function CnEccPointsEqual(P1, P2: TCnEccPoint): Boolean;
{* 判断两个 TCnEccPoint 点是否相等}

function CnEccDiffieHellmanGenerateOutKey(Ecc: TCnEcc; SelfPrivateKey: TCnEccPrivateKey;
  PublicKey: TCnEccPublicKey): Boolean;
{* 根据自身选择的随机数 PrivateKey 生成 ECDH 密钥协商的输出公钥点
   其中 PublicKey = SelfPrivateKey * G}

function CnEccDiffieHellmanComputeKey(Ecc: TCnEcc; SelfPrivateKey: TCnEccPrivateKey;
  OtherPublicKey: TCnEccPublicKey; SharedSecretKey: TCnEccPublicKey): Boolean;
{* 根据对方发送的 ECDH 密钥协商的输出公钥计算生成公认的密钥点，一般拿点的 X 坐标来做密钥
   其中 SecretKey = SelfPrivateKey * OtherPublicKey}

// ======================= 椭圆曲线密钥 PEM 读写实现 ===========================

function CnEccLoadKeysFromPem(const PemFileName: string; PrivateKey: TCnEccPrivateKey;
  PublicKey: TCnEccPublicKey; out CurveType: TCnEccCurveType;
  KeyHashMethod: TCnKeyHashMethod = ckhMd5; const Password: string = ''): Boolean;
{* 从 PEM 格式文件中加载公私钥数据，如某钥参数为空则不载入}

function CnEccSaveKeysToPem(const PemFileName: string; PrivateKey: TCnEccPrivateKey;
  PublicKey: TCnEccPublicKey; CurveType: TCnEccCurveType;
  KeyEncryptMethod: TCnKeyEncryptMethod = ckeNone;
  KeyHashMethod: TCnKeyHashMethod = ckhMd5; const Password: string = ''): Boolean;
{* 将公私钥写入 PEM 格式文件中，返回是否成功}

function CnEccLoadPublicKeyFromPem(const PemFileName: string;
  PublicKey: TCnEccPublicKey; out CurveType: TCnEccCurveType;
  KeyHashMethod: TCnKeyHashMethod = ckhMd5; const Password: string = ''): Boolean;
{* 从 PEM 格式文件中加载公钥数据，返回是否成功}

function CnEccSavePublicKeyToPem(const PemFileName: string;
  PublicKey: TCnEccPublicKey; CurveType: TCnEccCurveType;
  KeyType: TCnEccKeyType = cktPKCS1; KeyEncryptMethod: TCnKeyEncryptMethod = ckeNone;
  KeyHashMethod: TCnKeyHashMethod = ckhMd5; const Password: string = ''): Boolean;
{* 将公钥写入 PEM 格式文件中，返回是否成功}

// ========================= ECC 文件签名与验证实现 ============================
// 流与文件分开实现是因为计算文件摘要时支持大文件，而 FileStream 低版本不支持
// 注意 ECC 签名验证并不是像 RSA 那样解密后比对加密进去的 Hash 值
// 而是比对中间结果的大数，Ecc 签名内容并不能在验签名时还原原始 Hash 值

function CnEccSignFile(const InFileName, OutSignFileName: string; Ecc: TCnEcc;
  PrivateKey: TCnEccPrivateKey; SignType: TCnEccSignDigestType = esdtMD5): Boolean; overload;
{* 用私钥签名指定文件，Ecc 中需要预先指定曲线。
   使用指定数字摘要算法对文件进行计算得到散列值，
   原始的二进制散列值进行 BER 编码再 PKCS1 补齐再用私钥加密}

function CnEccSignFile(const InFileName, OutSignFileName: string; CurveType: TCnEccCurveType;
  PrivateKey: TCnEccPrivateKey; SignType: TCnEccSignDigestType = esdtMD5): Boolean; overload;
{* 用私钥签名指定文件，使用预定义曲线。
   使用指定数字摘要算法对文件进行计算得到散列值，
   原始的二进制散列值进行 BER 编码再 PKCS1 补齐再用私钥加密}

function CnEccVerifyFile(const InFileName, InSignFileName: string; Ecc: TCnEcc;
  PublicKey: TCnEccPublicKey; SignType: TCnEccSignDigestType = esdtMD5): Boolean; overload;
{* 用公钥与签名值验证指定文件，也即用指定数字摘要算法对文件进行计算得到散列值，
   并用公钥解密签名内容并解开 PKCS1 补齐再解开 BER 编码得到散列算法与散列值，
   并比对两个二进制散列值是否相同，返回验证是否通过。
   Ecc 中需要预先指定曲线。}

function CnEccVerifyFile(const InFileName, InSignFileName: string; CurveType: TCnEccCurveType;
  PublicKey: TCnEccPublicKey; SignType: TCnEccSignDigestType = esdtMD5): Boolean; overload;
{* 用预定义曲线与公钥与签名值验证指定文件，也即用指定数字摘要算法对文件进行计算得到散列值，
   并用公钥解密签名内容并解开 PKCS1 补齐再解开 BER 编码得到散列算法与散列值，
   并比对两个二进制散列值是否相同，返回验证是否通过}

function CnEccSignStream(InStream: TMemoryStream; OutSignStream: TMemoryStream;
  Ecc: TCnEcc; PrivateKey: TCnEccPrivateKey;
  SignType: TCnEccSignDigestType = esdtMD5): Boolean; overload;
{* 用私钥签名指定内存流，Ecc 中需要预先指定曲线}

function CnEccSignStream(InStream: TMemoryStream; OutSignStream: TMemoryStream;
  CurveType: TCnEccCurveType; PrivateKey: TCnEccPrivateKey;
  SignType: TCnEccSignDigestType = esdtMD5): Boolean; overload;
{* 用预定义曲线与私钥签名指定内存流}

function CnEccVerifyStream(InStream: TMemoryStream; InSignStream: TMemoryStream;
  Ecc: TCnEcc; PublicKey: TCnEccPublicKey;
  SignType: TCnEccSignDigestType = esdtMD5): Boolean; overload;
{* 用公钥与签名值验证指定内存流，Ecc 中需要预先指定曲线}

function CnEccVerifyStream(InStream: TMemoryStream; InSignStream: TMemoryStream;
  CurveType: TCnEccCurveType; PublicKey: TCnEccPublicKey;
  SignType: TCnEccSignDigestType = esdtMD5): Boolean; overload;
{* 用预定义曲线与公钥与签名值验证指定内存流}

// ===================== 基于有限扩域的多项式椭圆曲线运算 ======================

function CnInt64PolynomialEccPointToString(const P: TCnInt64PolynomialEccPoint): string;
{* 将一个 TCnInt64PolynomialEccPoint 点坐标转换为多项式字符串}

function CnInt64PolynomialEccPointsEqual(P1, P2: TCnInt64PolynomialEccPoint): Boolean;
{* 判断两个多项式点是否相等}

// ============================= 其他辅助函数 ==================================

function CheckEccPublicKey(Ecc: TCnEcc; PublicKey: TCnEccPublicKey): Boolean;
{* 检验给定曲线的 PublicKey 是否合法}

function GetCurveTypeFromOID(Data: PAnsiChar; DataLen: Cardinal): TCnEccCurveType;
{* 通过 BER 中的原始 OID 数据（包括头）获取对应的曲线类型}

function GetOIDFromCurveType(Curve: TCnEccCurveType; out OIDAddr: Pointer): Integer;
{* 根据曲线类型返回其 OID 地址与长度，外界使用后无需释放}

function ReadEccPublicKeyFromBitStringNode(BitStringNode: TCnBerReadNode;
  PublicKey: TCnEccPublicKey): Boolean;
{* 读取 BER 节点 BITSTRING 中的 ECC 公钥，返回是否成功}

function WriteEccPublicKeyToBitStringNode(Writer: TCnBerWriter;
  ParentNode: TCnBerWriteNode; PublicKey: TCnEccPublicKey): Boolean;
{* 将 ECC 公钥写入 BER 中的 BITSTRING 节点}

function GetEccDigestNameFromSignDigestType(Digest: TCnEccSignDigestType): string;
{* 从签名散列算法枚举值获取其名称}

procedure CnInt64GenerateGaloisDivisionPolynomials(A, B, Prime: Int64; MaxDegree: Integer;
  PolynomialList: TObjectList);
{* 批量生成 0 到 MaxDegree 阶的可除多项式，要确保和 Int64PolynomialGaloisCalcDivisionPolynomial
   的递归实现完全相同}

implementation

resourcestring
  SCnEccErrorCurveType = 'Invalid Curve Type.';
  SCnEccErrorKeyData = 'Invalid Key or Data.';

type
  TCnEccPredefinedHexParams = packed record
    P: AnsiString;
    A: AnsiString;
    B: AnsiString;
    X: AnsiString;
    Y: AnsiString;
    N: AnsiString;
    H: AnsiString;
  end;

const
  ECC_PRE_DEFINED_PARAMS: array[TCnEccCurveType] of TCnEccPredefinedHexParams = (
    (P: ''; A: ''; B: ''; X: ''; Y: ''; N: ''; H: ''),
    ( // SM2
      P: 'FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFF';
      A: 'FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000FFFFFFFFFFFFFFFC';
      B: '28E9FA9E9D9F5E344D5A9E4BCF6509A7F39789F515AB8F92DDBCBD414D940E93';
      X: '32C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7';
      Y: 'BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0';
      N: 'FFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFF7203DF6B21C6052B53BBF40939D54123';
      H: '01'
    ),
    ( // SM2 Example 192
      P: 'BDB6F4FE3E8B1D9E0DA8C0D46F4C318CEFE4AFE3B6B8551F';
      A: 'BB8E5E8FBC115E139FE6A814FE48AAA6F0ADA1AA5DF91985';
      B: '1854BEBDC31B21B7AEFC80AB0ECD10D5B1B3308E6DBF11C1';
      X: '4AD5F7048DE709AD51236DE65E4D4B482C836DC6E4106640';
      Y: '02BB3A02D4AAADACAE24817A4CA3A1B014B5270432DB27D2';
      N: 'BDB6F4FE3E8B1D9E0DA8C0D40FC962195DFAE76F56564677';
      H: '01'
    ),
    ( // SM2 Example 256
      P: '8542D69E4C044F18E8B92435BF6FF7DE457283915C45517D722EDB8B08F1DFC3';
      A: '787968B4FA32C3FD2417842E73BBFEFF2F3C848B6831D7E0EC65228B3937E498';
      B: '63E4C6D3B23B0C849CF84241484BFE48F61D59A5B16BA06E6E12D1DA27C5249A';
      X: '421DEBD61B62EAB6746434EBC3CC315E32220B3BADD50BDC4C4E6C147FEDD43D';
      Y: '0680512BCBB42C07D47349D2153B70C4E5D7FDFCBFA36EA1A85841B9E46E09A2';
      N: '8542D69E4C044F18E8B92435BF6FF7DD297720630485628D5AE74EE7C32E79B7';
      H: '01'
    ),
    ( // RFC 4754 ECDSA Example 256
      P: 'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF';
      A: '-03';
      B: '5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B';
      X: '6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296';
      Y: '4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5';
      N: 'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551';
      H: '01'
    ),
    ( // ctSecp224r1
      P: '00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF000000000000000000000001';
      A: '00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFE';
      B: '00B4050A850C04B3ABF54132565044B0B7D7BFD8BA270B39432355FFB4';
      X: 'B70E0CBD6BB4BF7F321390B94A03C1D356C21122343280D6115C1D21';
      Y: 'BD376388B5F723FB4C22DFE6CD4375A05A07476444D5819985007E34';
      N: '00FFFFFFFFFFFFFFFFFFFFFFFFFFFF16A2E0B8F03E13DD29455C5C2A3D';
      H: '01'
    ),
    ( // ctSecp224k1
      P: '00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFE56D';
      A: '00';
      B: '05';
      X: 'A1455B334DF099DF30FC28A169A467E9E47075A90F7E650EB6B7A45C';
      Y: '7E089FED7FBA344282CAFBD6F7E319F7C0B0BD59E2CA4BDB556D61A5';
      N: '010000000000000000000000000001DCE8D2EC6184CAF0A971769FB1F7';
      H: '01'
    ),
    ( // ctSecp256k1
      P: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F';
      A: '00';
      B: '07';
      X: '79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798';
      Y: '483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8';
      N: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141';
      H: '01'
    ),
    ( // ctPrime256v1
      P: 'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF';
      A: 'FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC';
      B: '5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B';
      X: '6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296';
      Y: '4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5';
      N: 'FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551';
      H: '01'
    )
  );

  PEM_EC_PARAM_HEAD = '-----BEGIN EC PARAMETERS-----';
  PEM_EC_PARAM_TAIL = '-----END EC PARAMETERS-----';

  PEM_EC_PRIVATE_HEAD = '-----BEGIN EC PRIVATE KEY-----';
  PEM_EC_PRIVATE_TAIL = '-----END EC PRIVATE KEY-----';

  PEM_EC_PUBLIC_HEAD = '-----BEGIN PUBLIC KEY-----';
  PEM_EC_PUBLIC_TAIL = '-----END PUBLIC KEY-----';

  // ECC 私钥文件里两个节点的 BER Tag 要求的特殊 TypeMask
  ECC_PRIVATEKEY_TYPE_MASK  = $80;

  // 公钥的存储形式
  EC_PUBLICKEY_COMPRESSED1  = 02;
  EC_PUBLICKEY_COMPRESSED2  = 03;
  EC_PUBLICKEY_UNCOMPRESSED = 04;

  // 预定义的椭圆曲线类型的 OID 及其最大长度
  EC_CURVE_TYPE_OID_MAX_LENGTH = 8;

  OID_ECPARAM_CURVE_TYPE_SECP256K1: array[0..4] of Byte = ( // 1.3.132.0.10
    $2B, $81, $04, $00, $0A
  );

  OID_ECPARAM_CURVE_TYPE_SM2: array[0..7] of Byte = (       // 1.2.156.10197.301
    $2A, $81, $1C, $CF, $55, $01, $82, $2D
  );

  OID_ECPARAM_CURVE_TYPE_PRIME256V1: array[0..7] of Byte = (  // 1.2.840.10045.3.1.7
    $2A, $86, $48, $CE, $3D, $03, $01, $07
  );

var
  FEccBigNumberPool: TCnBigNumberPool = nil;
  FEccInt64PolynomialPool: TCnInt64PolynomialPool = nil;

function Min(A, B: Integer): Integer;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

{* 取 X 的左边高 W 位，其中 W 是 N 的 BitsCount，该函数用于签名验签
   注意它和 SM2 中的同名函数功能不同}
procedure BuildShortXValue(X: TCnBigNumber; Order: TCnBigNumber);
var
  W: Integer;
begin
  W := X.GetBitsCount - Order.GetBitsCount;
  if W > 0 then
    BigNumberShiftRight(X, X, W);
end;

// 将一个 TCnInt64EccPoint 点坐标转换为字符串
function CnInt64EccPointToString(var P: TCnInt64EccPoint): string;
begin
  Result := Format('%d,%d', [P.X, P.Y]);
end;

// 将一个 TCnEccPoint 点坐标转换为十进制字符串
function CnEccPointToString(const P: TCnEccPoint): string;
begin
  Result := Format('%s,%s', [P.X.ToDec, P.Y.ToDec]);
end;

// 将一个 TCnEccPoint 点坐标转换为十六进制字符串
function CnEccPointToHex(const P: TCnEccPoint): string;
begin
  Result := Format('%s,%s', [P.X.ToHex, P.Y.ToHex]);
end;

// 判断两个点是否相等
function CnEccPointsEqual(P1, P2: TCnEccPoint): Boolean;
begin
  if P1 = P2 then
  begin
    Result := True;
    Exit;
  end;
  Result := (BigNumberCompare(P1.X, P2.X) = 0) and (BigNumberCompare(P1.Y, P2.Y) = 0);
end;

function CnInt64EccPointsEqual(var P1, P2: TCnInt64EccPoint): Boolean;
begin
  Result := (P1.X = P2.X) and (P1.Y = P2.Y);
end;

// 生成椭圆曲线 y^2 = x^3 + Ax + B mod p 的各个参数，难以实现
function CnInt64EccGenerateParams(var FiniteFieldSize, CoefficientA, CoefficientB,
  GX, GY, Order: Int64): Boolean;
var
  I: Integer;
  N: Int64;
  P: TCnInt64EccPoint;
  Ecc64: TCnInt64Ecc;
begin
  // 步骤：随机选有限域素数 p，与随机的 a、b，用 SEA 算法计算该曲线的阶 N
  // 判断 N 是大素数或其一半或三分之一是大素数，然后这个大素数作为循环子群的阶 n
  // 再根据 n 寻找基点 G 的坐标。如果 n 就等于 N 这个大素数，则 G 随便选都行。

  repeat
    // FiniteFieldSize := CnGenerateUInt32Prime; // 先用小点儿的素数，但也不能太小
    Randomize;
    I := Trunc(Random * (High(CN_PRIME_NUMBERS_SQRT_UINT32) - 100)) + 100;
    FiniteFieldSize := CN_PRIME_NUMBERS_SQRT_UINT32[I];
    CoefficientA := Trunc(Random * 16);
    CoefficientB := Trunc(Random * 256);
    N := 1; // 0,0 天然就算

    // A、B 都比较小，这里不用担心溢出
    if (4 * CoefficientA * CoefficientA * CoefficientA - 27 * CoefficientB * CoefficientB)
      mod FiniteFieldSize = 0 then
      Continue;

    GX := 0;
    GY := 0;

    // 以下求该椭圆曲线的阶，不懂 SEA，原先只能用特慢的穷举法，后改用勒让德公式
    // N := 1 + P + 所有的勒让德((x^3+ax+b)/p)之和，其中 X 从 0 到 P - 1
    Inc(N, FiniteFieldSize);
    for I := 0 to FiniteFieldSize - 1 do
    begin
      // 这里得用 Int64 先转换一下，否则 I 的三次方超过 Integer 溢出了
      N := N + CnInt64Legendre(Int64(I) * Int64(I) * Int64(I) + CoefficientA * I + CoefficientB, FiniteFieldSize);
    end;
  until CnInt64IsPrime(N);

  // 然后随机找一个 X 求 Y
  Ecc64 := TCnInt64Ecc.Create(CoefficientA, CoefficientB, FiniteFieldSize, 0, 0, FiniteFieldSize);
  repeat
    P.X := Trunc(Random * (FiniteFieldSize - 1)) + 1;
    for I := 0 to FiniteFieldSize - 1 do
    begin
      P.Y := I;
      if Ecc64.IsPointOnCurve(P) then
      begin
        GX := P.X;
        GY := P.Y;
        Break;
      end;
    end;
  until (GX > 0) and (GY > 0);
  Ecc64.Free;

//    以下代码用穷举法来验证 N 是否正确，目前小范围看起来基本上没错
//    N := 1;
//    Ecc64 := TCnInt64Ecc.Create(CoefficientA, CoefficientB, FiniteFieldSize, 0, 0, FiniteFieldSize);
//    for I := 0 to FiniteFieldSize - 1 do
//    begin
//      for J := 0 to FiniteFieldSize - 1 do
//      begin
//        P.X := I;
//        P.Y := J;
//        if Ecc64.IsPointOnCurve(P) then
//        begin
//          Inc(N);
//          if (GX = 0) or (GY = 0) then // 第一个满足的就当作基点
//          begin
//            GX := P.X;
//            GY := P.Y;
//          end;
//
//          if P.Y > 0 then
//          begin
//            P.Y := FiniteFieldSize - P.Y;
//            if Ecc64.IsPointOnCurve(P) then
//              Inc(N);
//          end;
//
//          // 这个 X 已经查完了，每个 X 不会有多于两个 Y。
//          Break;
//        end;
//      end;
//      // Break 到此，进行下一个 X 的循环
//    end;

    // N 为这条椭圆曲线的阶

  Order := N;
  Result := True;
end;

// 求 X 针对 M 的模反元素也就是模逆元 Y，满足 (X * Y) mod M = 1，范围为 Int64，也就是说支持 X 为负值
function Int64ModularInverse(X: Int64; Modulus: Int64): Int64;
var
  Neg: Boolean;
begin
  Neg := False;
  if X < 0 then
  begin
    X := -X;
    Neg := True;
  end;

  // 负数的模逆元，等于正数的模逆元的负值，负值还可以再加 Modulus
  Result := CnInt64ModularInverse(X, Modulus);
  if Neg and (Result > 0) then
    Result := -Result;

  if Result < 0 then
    Result := Result + Modulus;
end;

function RandomInt64LessThan(HighValue: Int64): Int64;
var
  Hi, Lo: Cardinal;
begin
  Randomize;
  Hi := Trunc(Random * High(Integer) - 1) + 1;   // Int64 最高位不能是 1，避免负数
  Randomize;
  Lo := Trunc(Random * High(Cardinal) - 1) + 1;
  Result := (Int64(Hi) shl 32) + Lo;
  Result := Result mod HighValue;
end;

{ TCnInt64Ecc }

constructor TCnInt64Ecc.Create(A, B, FieldPrime, GX, GY, Order: Int64);
var
  R: Int64;
begin
  inherited Create;

  // 由外界保证 Order 为素数
  if not CnInt64IsPrime(FieldPrime) then // or not CnInt64IsPrime(Order) then
    raise ECnEccException.Create('Infinite Field must be a Prime Number.');

  if not (GX >= 0) and (GX < FieldPrime) or
    not (GY >= 0) and (GY < FieldPrime) then
    raise ECnEccException.Create('Generator Point must be in Infinite Field.');

  // 要确保 4*a^3+27*b^2 <> 0
  if 4 * A * A * A + 27 * B * B = 0 then
    raise ECnEccException.Create('Error: 4 * A^3 + 27 * B^2 = 0');

  FCoefficientA := A;
  FCoefficientB := B;
  FFiniteFieldSize := FieldPrime;
  FGenerator.X := GX;
  FGenerator.Y := GY;
  FOrder := Order;

  R := FFiniteFieldSize mod 4;
  if R = 3 then  // RFC 5639 要求 p 满足 4u + 3 的形式以便方便地计算 Y，但其他曲线未必
  begin
    FSizePrimeType := pt4U3;
    FSizeUFactor := FFiniteFieldSize div 4;
  end
  else
  begin
    R := FFiniteFieldSize mod 8;
    if R = 1 then
    begin
      FSizePrimeType := pt8U1;
      FSizeUFactor := FFiniteFieldSize div 8;
    end
    else if R = 5 then
    begin
      FSizePrimeType := pt8U5;
      FSizeUFactor := FFiniteFieldSize div 8;
    end
    else
      raise ECnEccException.Create('Invalid Finite Field Size.');
  end;
end;

procedure TCnInt64Ecc.Decrypt(var DataPoint1, DataPoint2: TCnInt64EccPoint;
  PrivateKey: TCnInt64PrivateKey; var OutPlainPoint: TCnInt64EccPoint);
var
  P: TCnInt64EccPoint;
begin
  P := DataPoint2;
  MultiplePoint(PrivateKey, P);
  PointSubPoint(DataPoint1, P, OutPlainPoint);
end;

destructor TCnInt64Ecc.Destroy;
begin

  inherited;
end;

function TCnInt64Ecc.DivisionPolynomial(Degree: Integer;
  outDivisionPolynomial: TCnInt64Polynomial): Boolean;
begin
  Result := Int64PolynomialGaloisCalcDivisionPolynomial(FCoefficientA, FCoefficientB,
    Degree, outDivisionPolynomial, FFiniteFieldSize);
end;

procedure TCnInt64Ecc.Encrypt(var PlainPoint: TCnInt64EccPoint;
  PublicKey: TCnInt64PublicKey; var OutDataPoint1,
  OutDataPoint2: TCnInt64EccPoint; RandomKey: Int64);
begin
  if RandomKey = 0 then
  begin
    Randomize;
    RandomKey := Trunc(Random * (FOrder - 1)) + 1; // 比 0 大但比基点阶小的随机数
  end;

  if RandomKey mod FOrder = 0 then
    raise ECnEccException.CreateFmt('Error RandomKey %d for Order.', [RandomKey]);

  // M + rK;
  OutDataPoint1 := PublicKey;
  MultiplePoint(RandomKey, OutDataPoint1);
  PointAddPoint(PlainPoint, OutDataPoint1, OutDataPoint1);

  // r * G
  OutDataPoint2 := FGenerator;
  MultiplePoint(RandomKey, OutDataPoint2);
end;

procedure TCnInt64Ecc.GenerateKeys(out PrivateKey: TCnInt64PrivateKey;
  out PublicKey: TCnInt64PublicKey);
begin
  Randomize;
  PrivateKey := Trunc(Random * (FOrder - 1)) + 1; // 比 0 大但比基点阶小的随机数
  PublicKey := FGenerator;
  MultiplePoint(PrivateKey, PublicKey);           // 基点乘 PrivateKey 次
end;

function TCnInt64Ecc.IsPointOnCurve(var P: TCnInt64EccPoint): Boolean;
var
  Y2, X3, AX, B: Int64;
begin
  // 计算 (Y^2 - X^3 - A*X - B) mod p 是否等于 0，应用分配律
  // 也就是计算(Y^2 mod p - X^3 mod p - A*X mod p - B mod p) mod p
  Y2 := MontgomeryPowerMod(P.Y, 2, FFiniteFieldSize);
  X3 := MontgomeryPowerMod(P.X, 3, FFiniteFieldSize);
  AX := Int64MultipleMod(FCoefficientA, P.X, FFiniteFieldSize);
  B := FCoefficientB mod FFiniteFieldSize;

  Result := ((Y2 - X3 - AX - B) mod FFiniteFieldSize) = 0;
end;

function TCnInt64Ecc.Lucas(X, P: Int64; out Y: Int64): Boolean;
var
  G, U, V, Z: Int64;
begin
  Result := False;
  G := X;

  while True do
  begin
    // 随机取 X
    X := RandomInt64LessThan(P);

    // 再计算 Lucas 序列中的 V，其下标 K 为 (P+1)/2
    CnLucasSequenceMod(X, G, (P + 1) shr 1, P, U, V);

    // V 偶则直接右移 1 再 mod P，V 奇则加 P 再右移 1
    if (V and 1) = 0 then
      Z := (V shr 1) mod P
    else
      Z := (V + P) shr 1;
    // Z := (V div 2) mod P;

    if Int64MultipleMod(Z, Z, P) = G then
    begin
      Y := Z;
      Result := True;
      Exit;
    end
    else if (U > 1) and (U < P - 1) then
      Break;
  end;
end;

procedure TCnInt64Ecc.MultiplePoint(K: Int64; var Point: TCnInt64EccPoint);
var
  E, R: TCnInt64EccPoint;
begin
  if K < 0 then
  begin
    K := -K;
    PointInverse(Point);
  end;

  if K = 0 then
  begin
    Point.X := 0;
    Point.Y := 0;
    Exit;
  end;

  if K > 1 then
  begin
    R.X := 0;
    R.Y := 0;
    E := Point;

    while K <> 0 do
    begin
      if (K and 1) <> 0 then
        PointAddPoint(R, E, R);

      PointAddPoint(E, E, E);
      K := K shr 1;
    end;

    Point := R;
  end;
end;

function TCnInt64Ecc.PlainToPoint(Plain: Int64;
  var OutPoint: TCnInt64EccPoint): Boolean;
var
  X3, AX, B, G, Y, Z: Int64;
begin
  Result := False;
  if Plain = 0 then
  begin
    OutPoint.X := 0;
    OutPoint.Y := 0;
    Result := True;
    Exit;
  end;

  // 解方程求 Y： (y^2 - (Plain^3 + A * Plain + B)) mod p = 0
  // 注意 Plain 如果太大，计算过程中会溢出，不好处理，只能用分配律。
  // (Y^2 mod p - Plain ^ 3 mod p - A * Plain mod p - B mod p) mod p = 0;
  X3 := MontgomeryPowerMod(Plain, 3, FFiniteFieldSize);
  AX := Int64MultipleMod(FCoefficientA, Plain, FFiniteFieldSize);
  B := FCoefficientB mod FFiniteFieldSize;

  G := (X3 + AX + B) mod FFiniteFieldSize; // 如果不溢出的话
  if G = 0 then   // 如果 X^3 + AX + B 为 0，则直接返回 (Plain, 0) 并且肯定满足曲线方程
  begin
    OutPoint.X := Plain;
    OutPoint.Y := 0;
    Result := True;
    Exit;
  end;

  // 化为 Y^2 = N * p + B 要求找出 N 让右边为完全平方数，再求 Y 的正值
  // 要是硬算 N 从 0 开始加 1 遍历并开方计算是否完全平方数会特慢，不能这么整
  // 改用二次剩余素数模的快速求法，根据素数 P 的特性分三种：

  case FSizePrimeType of
  pt4U3:  // 参考自《SM2椭圆曲线公钥密码算法》附录 B 中的“模素数平方根的求解”一节
    begin
      Y := MontgomeryPowerMod(G, FSizeUFactor + 1, FFiniteFieldSize);
      Z := Int64MultipleMod(Y, Y, FFiniteFieldSize);
      if Z = G then
      begin
        OutPoint.X := Plain;
        OutPoint.Y := Y;
        Result := True;
      end;
    end;
  pt8U5:  // 参考自《SM2椭圆曲线公钥密码算法》附录 B 中的“模素数平方根的求解”一节
    begin
      Z := MontgomeryPowerMod(G, 2 * FSizeUFactor + 1, FFiniteFieldSize);
      if Z = 1 then
      begin
        Y := MontgomeryPowerMod(G, FSizeUFactor + 1, FFiniteFieldSize);
        OutPoint.X := Plain;
        OutPoint.Y := Y;
        Result := True;
      end
      else
      begin
        Z := FFiniteFieldSize - Z;
        if Z = 1 then
        begin
          // y = (2g * (4g)^u) mod p = (2g mod p * (4^u * g^u) mod p) mod p
          Y := (Int64MultipleMod(G, 2, FFiniteFieldSize) *
            MontgomeryPowerMod(4, FSizeUFactor, FFiniteFieldSize) *
            MontgomeryPowerMod(G, FSizeUFactor, FFiniteFieldSize)) mod FFiniteFieldSize;
          OutPoint.X := Plain;
          OutPoint.Y := Y;
          Result := True;
        end;
      end;
    end;
  pt8U1: // 参考自 wikipedia 上的 Tonelli-Shanks 二次剩余求解算法以及 IEEE P1363 里的 Lucas 序列算法
    begin
{$IFDEF USE_LUCAS}
      // 《SM2椭圆曲线公钥密码算法》附录 B 中的“模素数平方根的求解”一节 Lucas 序列计算出来的结果实在不对
      if Lucas(G, FFiniteFieldSize, Y) then
      begin
        OutPoint.X := Plain;
        OutPoint.Y := Y;
        Result := True;
      end;
{$ELSE}
      //  改用 Tonelli-Shanks 算法进行模素数二次剩余求解，但内部先要通过勒让德符号判断其根是否存在，否则会陷入死循环
      if TonelliShanks(G, FFiniteFieldSize, Y) then
      begin
        OutPoint.X := Plain;
        OutPoint.Y := Y;
        Result := True;
      end;
{$ENDIF}
    end;
  end;
end;

procedure TCnInt64Ecc.PointAddPoint(var P, Q, Sum: TCnInt64EccPoint);
var
  K, X, Y, PX: Int64;
begin
  K := 0;
  if (P.X = 0) and (P.Y = 0) then
  begin
    Sum := Q;
    Exit;
  end
  else if (Q.X = 0) and (Q.Y = 0) then
  begin
    Sum := P;
    Exit;
  end
  else if (P.X = Q.X) and (P.Y = Q.Y) then
  begin
    // 俩加数是同一个点，切线斜率为两边求导，3 * X^2 + A / (2 * Y) 但如 Y = 0 则直接是无限远 0。
    X := 3 * P.X * P.X + FCoefficientA;
    Y := 2 * P.Y;

    if Y = 0 then
    begin
      Sum.X := 0;
      Sum.Y := 0;
    end;

    Y := Int64ModularInverse(Y, FFiniteFieldSize);
    K := Int64MultipleMod(X, Y, FFiniteFieldSize); // 得到斜率
  end
  else if (P.X = Q.X) and ((P.Y = -Q.Y) or (P.Y + Q.Y = FFiniteFieldSize)) then        // P = -Q
  begin
    Sum.X := 0;
    Sum.Y := 0;
    Exit;
  end
  else if P.X <> Q.X then
  begin
    // 斜率 K := ((Q.Y - P.Y) / (Q.X - P.X)) mod p
    Y := Q.Y - P.Y;
    X := Q.X - P.X;

    // Y/X = Y*X^-1 = Y * (X 针对 p 的逆元)
    X := Int64ModularInverse(X, FFiniteFieldSize);
    K := Int64MultipleMod(Y, X, FFiniteFieldSize); // 得到斜率
  end
  else if P.Y <> Q.Y then
  begin
    // P、Q 两点 X 相同，Y 不同但又不是逆元，该如何相加？理论上不会出现
    raise ECnEccException.CreateFmt('Can NOT Calucate %d,%d + %d,%d', [P.X, P.Y, Q.X, Q.Y]);
  end;

  // Xsum = (K^2 - X1 - X2) mod p
  X := K * K - P.X - Q.X;
  while X < 0 do
    X := X + FFiniteFieldSize;
  PX := P.X; // 如果 Sum 和 P 是同一个，要避免 P.X 被冲掉，因而得先存着 P.X
  if X < 0 then
  begin
    X := -X;
    Sum.X := X mod FFiniteFieldSize;
    if Sum.X > 0 then                      // 如果 X 刚好整除，则是 0
      Sum.X := FFiniteFieldSize - Sum.X;
  end
  else
    Sum.X := X mod FFiniteFieldSize;

  // Ysum = (K * (X1 - Xsum) - Y1) mod p  注意要取负
  //   也 = (K * (X2 - Xsum) - Y2) mod p  注意要取负
  X := PX - Sum.X;
  Y := K * X - P.Y;
  if Y < 0 then
  begin
    Y := -Y;
    Sum.Y := Y mod FFiniteFieldSize;
    if Sum.Y > 0 then                      // 如果 Y 刚好整除，则是 0
      Sum.Y := FFiniteFieldSize - Sum.Y;
  end
  else
    Sum.Y := Y mod FFiniteFieldSize;
end;

procedure TCnInt64Ecc.PointInverse(var P: TCnInt64EccPoint);
begin
  // P.Y := -P.Y mod p 注意这里的负值取模不等于 Delphi 的取正后取模再变负
  P.Y := FFiniteFieldSize - (P.Y mod FFiniteFieldSize);
end;

procedure TCnInt64Ecc.PointSubPoint(var P, Q, Diff: TCnInt64EccPoint);
var
  Inv: TCnInt64EccPoint;
begin
  Inv.X := Q.X;
  Inv.Y := Q.Y;
  PointInverse(Inv);
  PointAddPoint(P, Inv, Diff);
end;

// 根据自身选择的随机数 PrivateKey 生成 ECDH 密钥协商的输出公钥点
function CnInt64EccDiffieHellmanGenerateOutKey(Ecc: TCnInt64Ecc; SelfPrivateKey: TCnInt64PrivateKey;
  out PublicKey: TCnInt64PublicKey): Boolean;
begin
  // OutPublicKey = SelfPrivateKey * G
  Result := False;
  if (Ecc <> nil) and (SelfPrivateKey > 0) then
  begin
    PublicKey := Ecc.Generator;
    Ecc.MultiplePoint(SelfPrivateKey, PublicKey);
    Result := True;
  end;
end;

// 根据对方发送的 ECDH 密钥协商的输出公钥计算生成公认的密钥点
function CnInt64EccDiffieHellmanComputeKey(Ecc: TCnInt64Ecc; SelfPrivateKey: TCnInt64PrivateKey;
  var OtherPublicKey: TCnInt64PublicKey; var SharedSecretKey: TCnInt64PublicKey): Boolean;
begin
  // SecretKey = SelfPrivateKey * OtherPublicKey
  Result := False;
  if (Ecc <> nil) and (SelfPrivateKey > 0) then
  begin
    SharedSecretKey := OtherPublicKey;
    Ecc.MultiplePoint(SelfPrivateKey, SharedSecretKey);
    Result := True;
  end;
end;

function TCnInt64Ecc.TonelliShanks(X, P: Int64; out Y: Int64): Boolean;
var
  I: Integer;
  Q, S, Z, C, R, T, M, B: Int64;
begin
  Result := False;
  if (X <= 0) or (P <= 0) or (X >= P) then
    Exit;

  // 先要通过勒让德符号判断其根是否存在，否则下面会陷入死循环
  if CnInt64Legendre(X, P) <> 1 then
    Exit;

  S := 0;
  Q := P - 1;
  while (Q mod 2) = 0 do
  begin
    Q := Q shr 1;
    Inc(S);
  end;

  Z := 2;
  while Z < P do
  begin
    if CnInt64Legendre(Z, P) = -1 then
      Break;
    Inc(Z);
  end;

  // 先找一个 Z 满足 针对 P 的勒让德符号为 -1
  C := MontgomeryPowerMod(Z, Q, P);
  R := MontgomeryPowerMod(X, (Q + 1) div 2, P);
  T := MontgomeryPowerMod(X, Q, P);
  M := S;

  while True do
  begin
    if T mod P = 1 then
      Break;

    for I := 1 to M - 1 do
    begin
      if MontgomeryPowerMod(T, 1 shl I, P) = 1 then
        Break;
    end;

    B := MontgomeryPowerMod(C, 1 shl (M - I - 1), P);
    M := I; // M 每回都会减小，算法收敛

    R := Int64MultipleMod(R, B, P);
    T := Int64MultipleMod(Int64MultipleMod(T, B, P),
      B mod P, P); // T*B*B mod P = (T*B mod P) * (B mod P) mod P
    C := Int64MultipleMod(B, B, P);
  end;
  Y := (R mod P + P) mod P;
  Result := True;
end;

{ TCnEccPoint }

procedure TCnEccPoint.Assign(Source: TPersistent);
begin
  if Source is TCnEccPoint then
  begin
    BigNumberCopy(FX, (Source as TCnEccPoint).X);
    BigNumberCopy(FY, (Source as TCnEccPoint).Y);
  end
  else
    inherited;
end;

constructor TCnEccPoint.Create;
begin
  inherited;
  FX := TCnBigNumber.Create;
  FY := TCnBigNumber.Create;
  FX.SetZero;
  FY.SetZero;
end;

constructor TCnEccPoint.Create(const XDec, YDec: AnsiString);
begin
  Create;
  FX.SetDec(XDec);
  FY.SetDec(YDec);
end;

destructor TCnEccPoint.Destroy;
begin
  FY.Free;
  FX.Free;
  inherited;
end;

function TCnEccPoint.IsZero: Boolean;
begin
  Result := FX.IsZero and FY.IsZero;
end;

procedure TCnEccPoint.SetX(const Value: TCnBigNumber);
begin
  BigNumberCopy(FX, Value);
end;

procedure TCnEccPoint.SetY(const Value: TCnBigNumber);
begin
  BigNumberCopy(FY, Value);
end;

procedure TCnEccPoint.SetZero;
begin
  FX.SetZero;
  FY.SetZero;
end;

{ TCnEcc }

procedure TCnEcc.CalcX3AddAXAddB(X: TCnBigNumber);
var
  M: TCnBigNumber;
begin
  M := FEccBigNumberPool.Obtain;
  try
    BigNumberCopy(M, X);
    BigNumberMul(X, X, X);
    BigNumberMul(X, X, M); // X: X^3

    BigNumberMul(M, M, FCoefficientA); // M: A*X
    BigNumberAdd(X, X, M);             // X: X^3 + A*X
    BigNumberAdd(X, X, FCoefficientB); // X: X^3 + A*X + B
  finally
    FEccBigNumberPool.Recycle(M);
  end;
end;

constructor TCnEcc.Create(const A, B, FieldPrime, GX, GY, Order: AnsiString; H: Integer);
begin
  Create;
  Load(A, B, FIeldPrime, GX, GY, Order, H);
end;

constructor TCnEcc.Create;
begin
  inherited;
  FGenerator := TCnEccPoint.Create;
  FCoefficientB := TCnBigNumber.Create;
  FCoefficientA := TCnBigNumber.Create;
  FOrder := TCnBigNumber.Create;
  FFiniteFieldSize := TCnBigNumber.Create;

  FSizeUFactor := TCnBigNumber.Create;
end;

constructor TCnEcc.Create(Predefined: TCnEccCurveType);
begin
  Create;
  Load(Predefined);
end;

procedure TCnEcc.Decrypt(DataPoint1, DataPoint2: TCnEccPoint;
  PrivateKey: TCnEccPrivateKey; OutPlainPoint: TCnEccPoint);
var
  P: TCnEccPoint;
begin
  if (BigNumberCompare(PrivateKey, CnBigNumberZero) <= 0) or
    not IsPointOnCurve(DataPoint1) or not IsPointOnCurve(DataPoint2) then
    raise ECnEccException.Create('Invalid Private Key or Data.');

  P := TCnEccPoint.Create;
  try
    P.Assign(DataPoint2);
    MultiplePoint(PrivateKey, P);
    PointSubPoint(DataPoint1, P, OutPlainPoint);
  finally
    P.Free;
  end;
end;

destructor TCnEcc.Destroy;
begin
  FSizeUFactor.Free;

  FGenerator.Free;
  FCoefficientB.Free;
  FCoefficientA.Free;
  FOrder.Free;
  FFiniteFieldSize.Free;
  inherited;
end;

procedure TCnEcc.Encrypt(PlainPoint: TCnEccPoint;
  PublicKey: TCnEccPublicKey; OutDataPoint1, OutDataPoint2: TCnEccPoint);
var
  RandomKey: TCnBigNumber;
begin
  if not IsPointOnCurve(PublicKey) or not IsPointOnCurve(PlainPoint) then
    raise ECnEccException.Create(SCnEccErrorKeyData);

  RandomKey := FEccBigNumberPool.Obtain;
  try
    BigNumberRandRange(RandomKey, FOrder);    // 比 0 大但比基点阶小的随机数
    if BigNumberIsZero(RandomKey) then
      BigNumberSetOne(RandomKey);

    // M + rK;
    OutDataPoint1.Assign(PublicKey);
    MultiplePoint(RandomKey, OutDataPoint1);
    PointAddPoint(PlainPoint, OutDataPoint1, OutDataPoint1);

    // r * G
    OutDataPoint2.Assign(FGenerator);
    MultiplePoint(RandomKey, OutDataPoint2);
  finally
    FEccBigNumberPool.Recycle(RandomKey);
  end;
end;

procedure TCnEcc.GenerateKeys(PrivateKey: TCnEccPrivateKey;
  PublicKey: TCnEccPublicKey);
begin
  BigNumberRandRange(PrivateKey, FOrder);           // 比 0 大但比基点阶小的随机数
  if PrivateKey.IsZero then                         // 万一真拿到 0，就加 1
    PrivateKey.SetOne;

  PublicKey.Assign(FGenerator);
  MultiplePoint(PrivateKey, PublicKey);             // 基点乘 PrivateKey 次
end;

function TCnEcc.GetBitsCount: Integer;
begin
  Result := FFiniteFieldSize.GetBitsCount;
end;

function TCnEcc.IsPointOnCurve(P: TCnEccPoint): Boolean;
var
  X, Y, A: TCnBigNumber;
begin
  X := FEccBigNumberPool.Obtain;
  Y := FEccBigNumberPool.Obtain;
  A := FEccBigNumberPool.Obtain;

  try
    BigNumberCopy(X, P.X);
    BigNumberCopy(Y, P.Y);

    BigNumberMul(Y, Y, Y);                // Y: Y^2
    BigNumberMod(Y, Y, FFiniteFieldSize); // Y^2 mod P

    CalcX3AddAXAddB(X);                   // X: X^3 + A*X + B
    BigNumberMod(X, X, FFiniteFieldSize); // X: (X^3 + A*X + B) mod P
    Result := BigNumberCompare(X, Y) = 0;
  finally
    FEccBigNumberPool.Recycle(X);
    FEccBigNumberPool.Recycle(Y);
    FEccBigNumberPool.Recycle(A);
  end;
end;

procedure TCnEcc.Load(Predefined: TCnEccCurveType);
begin
  Load(ECC_PRE_DEFINED_PARAMS[Predefined].A, ECC_PRE_DEFINED_PARAMS[Predefined].B,
    ECC_PRE_DEFINED_PARAMS[Predefined].P, ECC_PRE_DEFINED_PARAMS[Predefined].X,
    ECC_PRE_DEFINED_PARAMS[Predefined].Y, ECC_PRE_DEFINED_PARAMS[Predefined].N,
    StrToIntDef(ECC_PRE_DEFINED_PARAMS[Predefined].H, 1));
end;

procedure TCnEcc.Load(const A, B, FieldPrime, GX, GY, Order: AnsiString; H: Integer);
var
  R: DWORD;
begin
  FGenerator.X.SetHex(GX);
  FGenerator.Y.SetHex(GY);
  FCoefficientA.SetHex(A);
  FCoefficientB.SetHex(B);
  FFiniteFieldSize.SetHex(FieldPrime);
  FOrder.SetHex(Order);
  FCoFactor := H;

  // TODO: 要确保 4*a^3+27*b^2 <> 0

//  由调用者保证有限域边界为素数
//  if not BigNumberIsProbablyPrime(FFiniteFieldSize) then
//    raise ECnEccException.Create('Error: Finite Field Size must be Prime.');

  // 确定 PrimeType
  R := BigNumberModWord(FFiniteFieldSize, 4);
  BigNumberCopy(FSizeUFactor, FFiniteFieldSize);
  if R = 3 then  // RFC 5639 要求 p 满足 4u + 3 的形式以便方便地计算 Y，但其他曲线未必
  begin
    FSizePrimeType := pt4U3;
    BigNumberDivWord(FSizeUFactor, 4);
  end
  else
  begin
    R := BigNumberModWord(FFiniteFieldSize, 8);
    if R = 1 then
    begin
      FSizePrimeType := pt8U1;
      BigNumberDivWord(FSizeUFactor, 8);
    end
    else if R = 5 then
    begin
      FSizePrimeType := pt8U5;
      BigNumberDivWord(FSizeUFactor, 8);
    end
    else
      raise ECnEccException.Create('Invalid Finite Field Size.');
  end;
end;

procedure TCnEcc.MultiplePoint(K: TCnBigNumber; Point: TCnEccPoint);
var
  I: Integer;
  E, R: TCnEccPoint;
begin
  if BigNumberIsNegative(K) then
  begin
    BigNumberSetNegative(K, False);
    PointInverse(Point);
  end;

  if BigNumberIsZero(K) then
  begin
    Point.SetZero;
    Exit;
  end;

  R := nil;
  E := nil;

  try
    R := TCnEccPoint.Create;
    E := TCnEccPoint.Create;
    E.X := Point.X;
    E.Y := Point.Y;

    for I := 0 to BigNumberGetBitsCount(K) - 1 do
    begin
      if BigNumberIsBitSet(K, I) then
        PointAddPoint(R, E, R);
      PointAddPoint(E, E, E);
    end;

    Point.X := R.X;
    Point.Y := R.Y;
  finally
    R.Free;
    E.Free;
  end;
end;

function TCnEcc.PlainToPoint(Plain: TCnBigNumber;
  OutPoint: TCnEccPoint): Boolean;
var
  X, Y, Z, U, R, T, L, X3, C, M: TCnBigNumber;
begin
  Result := False;
  if Plain.IsNegative then
    Exit;

  if BigNumberCompare(Plain, FFiniteFieldSize) >= 0 then
    Exit;

  X := nil;
  U := nil;
  Y := nil;
  Z := nil;
  R := nil;
  T := nil;
  L := nil;
  X3 := nil;
  C := nil;
  M := nil;

  try
    X := FEccBigNumberPool.Obtain;
    Y := FEccBigNumberPool.Obtain;
    Z := FEccBigNumberPool.Obtain;
    U := FEccBigNumberPool.Obtain;
    X3 := FEccBigNumberPool.Obtain;

    BigNumberCopy(X, Plain);
    BigNumberCopy(U, FSizeUFactor);

    CalcX3AddAXAddB(X);
    BigNumberMod(X, X, FFiniteFieldSize);
    BigNumberCopy(X3, X);    // 保存原始 g

    if X3.IsZero then // 如果 (X^3 + AX + B) mod p 为 0，则直接返回 (Plain, 0) 并且肯定满足曲线方程
    begin
      BigNumberCopy(OutPoint.X, Plain);
      OutPoint.Y.SetZero;
      Result := True;
      Exit;
    end;

    // 参考自《SM2椭圆曲线公钥密码算法》附录 B 中的“模素数平方根的求解”一节，这里 g 是 X 经过运算后的方程右半部分值
    case FSizePrimeType of
      pt4U3:
        begin
          // 结果是 g^(u+1) mod p
          BigNumberAddWord(U, 1);
          BigNumberMontgomeryPowerMod(Y, X, U, FFiniteFieldSize);
          BigNumberMulMod(Z, Y, Y, FFiniteFieldSize);
          if BigNumberCompare(Z, X) = 0 then
          begin
            BigNumberCopy(OutPoint.X, Plain);
            BigNumberCopy(OutPoint.Y, Y);
            Result := True;
            Exit;
          end;
        end;
      pt8U5:
        begin
          BigNumberMulWord(U, 2);
          BigNumberAddWord(U, 1);
          BigNumberMontgomeryPowerMod(Z, X, U, FFiniteFieldSize);
          R := FEccBigNumberPool.Obtain;
          BigNumberMod(R, Z, FFiniteFieldSize);

          if R.IsOne then
          begin
            // 结果是 g^(u+1) mod p
            BigNumberCopy(U, FSizeUFactor);
            BigNumberAddWord(U, 1);
            BigNumberMontgomeryPowerMod(Y, X, U, FFiniteFieldSize);

            BigNumberCopy(OutPoint.X, Plain);
            BigNumberCopy(OutPoint.Y, Y);
            Result := True;
          end
          else
          begin
            if R.IsNegative then
              BigNumberAdd(R, R, FFiniteFieldSize);
            BigNumberSub(R, FFiniteFieldSize, R);
            if R.IsOne then
            begin
              // 结果是(2g ·(4g)^u) mod p = (2g mod p * (4g)^u mod p) mod p
              BigNumberCopy(X, X3);
              BigNumberMulWord(X, 2);
              BigNumberMod(R, X, FFiniteFieldSize);  // R: 2g mod p

              BigNumberCopy(X, X3);
              BigNumberMulWord(X, 4);
              T := FEccBigNumberPool.Obtain;
              BigNumberMontgomeryPowerMod(T, X, FSizeUFactor, FFiniteFieldSize); // T: (4g)^u mod p
              BigNumberMulMod(Y, R, T, FFiniteFieldSize);

              BigNumberCopy(OutPoint.X, Plain);
              BigNumberCopy(OutPoint.Y, Y);
              Result := True;
            end;
          end;
        end;
      pt8U1: // Lucas 序列计算法与 Tonelli-Shanks 算法均能进行模素数二次剩余求解
        begin
{$IFDEF USE_LUCAS}
          if BigNumberLucas(OutPoint.Y, X3, FFiniteFieldSize) then
          begin
            BigNumberCopy(OutPoint.X, Plain);
            Result := True;
          end;
{$ELSE}
          if BigNumberTonelliShanks(OutPoint.Y, X3, FFiniteFieldSize) then
          begin
            BigNumberCopy(OutPoint.X, Plain);
            Result := True;
          end;
{$ENDIF}
        end;
    end;
  finally
    FEccBigNumberPool.Recycle(X);
    FEccBigNumberPool.Recycle(Y);
    FEccBigNumberPool.Recycle(Z);
    FEccBigNumberPool.Recycle(U);
    FEccBigNumberPool.Recycle(R);
    FEccBigNumberPool.Recycle(T);
    FEccBigNumberPool.Recycle(L);
    FEccBigNumberPool.Recycle(X3);
    FEccBigNumberPool.Recycle(C);
    FEccBigNumberPool.Recycle(M);
  end;
end;

procedure TCnEcc.PointAddPoint(P, Q, Sum: TCnEccPoint);
var
  K, X, Y, A, SX, SY: TCnBigNumber;
begin
  K := nil;
  X := nil;
  Y := nil;
  A := nil;
  SX := nil;
  SY := nil;

  try
    if P.IsZero then
    begin
      Sum.Assign(Q);
      Exit;
    end
    else if Q.IsZero then
    begin
      Sum.Assign(P);
      Exit;
    end
    else if (BigNumberCompare(P.X, Q.X) = 0) and (BigNumberCompare(P.Y, Q.Y) = 0) then
    begin
      // 俩加数是同一个点，切线斜率为两边求导，3 * X^2 + A / (2 * Y) 但如 Y = 0 则直接是无限远 0。
      if P.Y.IsZero then
      begin
        Sum.SetZero;
        Exit;
      end;

      X := FEccBigNumberPool.Obtain;
      Y := FEccBigNumberPool.Obtain;
      K := FEccBigNumberPool.Obtain;

      // X := 3 * P.X * P.X + CoefficientA;
      BigNumberMul(X, P.X, P.X);             // X: P.X^2
      BigNumberMulWord(X, 3);                // X: 3 * P.X^2
      BigNumberAdd(X, X, FCoefficientA);     // X: 3 * P.X^2 + A

      // Y := 2 * P.Y;
      BigNumberCopy(Y, P.Y);
      BigNumberMulWord(Y, 2);                // Y: 2 * P.Y

      A := FEccBigNumberPool.Obtain;
      BigNumberCopy(A, Y);
      BigNumberModularInverse(Y, A, FFiniteFieldSize); // Y := Y^-1

      // K := X * Y mod FFiniteFieldSize;
      BigNumberMulMod(K, X, Y, FFiniteFieldSize);      // 得到斜率
    end
    else // 是不同点
    begin
      if BigNumberCompare(P.X, Q.X) = 0 then // 如果 X 相等，要判断 Y 是不是互反，是则和为 0，不是则挂了
      begin
        A := FEccBigNumberPool.Obtain;
        BigNumberAdd(A, P.Y, Q.Y);
        if BigNumberCompare(A, FFiniteFieldSize) = 0 then  // 互反，和为 0
          Sum.SetZero
        else                                               // 不互反，挂了
          raise ECnEccException.CreateFmt('Can NOT Calucate %s,%s + %s,%s',
            [P.X.ToDec, P.Y.ToDec, Q.X.ToDec, Q.Y.ToDec]);

        Exit;
      end;

      // 到这里，X 确定不同，斜率 K := ((Q.Y - P.Y) / (Q.X - P.X)) mod p
      X := FEccBigNumberPool.Obtain;
      Y := FEccBigNumberPool.Obtain;
      K := FEccBigNumberPool.Obtain;

      // Y := Q.Y - P.Y;
      // X := Q.X - P.X;
      BigNumberSub(Y, Q.Y, P.Y);
      BigNumberSub(X, Q.X, P.X);

      A := FEccBigNumberPool.Obtain;
      BigNumberCopy(A, X);
      BigNumberModularInverse(X, A, FFiniteFieldSize);
      BigNumberMulMod(K, Y, X, FFiniteFieldSize);      // 得到斜率
    end;

    BigNumberCopy(X, K);
    BigNumberMul(X, X, K);
    BigNumberSub(X, X, P.X);
    BigNumberSub(X, X, Q.X);    //  X := K * K - P.X - Q.X;

    SX := FEccBigNumberPool.Obtain;
    if BigNumberIsNegative(X) then // 负值的模等于正值的模被模数减
    begin
      BigNumberSetNegative(X, False);
      BigNumberMod(SX, X, FFiniteFieldSize);
      if not SX.IsZero then                   // 刚好整除时无需减，保持 0，避免出现 X 值等于有限域上界的情况
        BigNumberSub(SX, FFiniteFieldSize, SX);
    end
    else
      BigNumberMod(SX, X, FFiniteFieldSize);

    // Ysum = (K * (X1 - Xsum) - Y1) mod p  注意要取负
    //   也 = (K * (X2 - Xsum) - Y2) mod p  注意要取负
    BigNumberSub(X, P.X, SX);
    BigNumberMul(Y, K, X);
    BigNumberSub(Y, Y, P.Y);

    SY := FEccBigNumberPool.Obtain;
    if BigNumberIsNegative(Y) then
    begin
      BigNumberSetNegative(Y, False);
      BigNumberMod(SY, Y, FFiniteFieldSize);
      if not SY.IsZero then                     // 刚好整除时无需减，保持 0，避免出现 Y 值等于有限域上界的情况
        BigNumberSub(SY, FFiniteFieldSize, SY);
    end
    else
      BigNumberMod(SY, Y, FFiniteFieldSize);

    BigNumberCopy(Sum.X, SX);
    BigNumberCopy(Sum.Y, SY);
  finally
    FEccBigNumberPool.Recycle(K);
    FEccBigNumberPool.Recycle(X);
    FEccBigNumberPool.Recycle(Y);
    FEccBigNumberPool.Recycle(A);
    FEccBigNumberPool.Recycle(SX);
    FEccBigNumberPool.Recycle(SY);
  end;
end;

procedure TCnEcc.PointInverse(P: TCnEccPoint);
begin
  if BigNumberIsNegative(P.Y) or (BigNumberCompare(P.Y, FFiniteFieldSize) >= 0) then
    raise ECnEccException.Create('Inverse Error.');

  BigNumberSub(P.Y, FFiniteFieldSize, P.Y);
end;

procedure TCnEcc.PointSubPoint(P, Q, Diff: TCnEccPoint);
var
  Inv: TCnEccPoint;
begin
  Inv := TCnEccPoint.Create;
  try
    Inv.X := Q.X;
    Inv.Y := Q.Y;

    PointInverse(Inv);
    PointAddPoint(P, Inv, Diff);
  finally
    Inv.Free;
  end;
end;

function TCnEcc.PointToPlain(Point: TCnEccPoint;
  OutPlain: TCnBigNumber): Boolean;
begin
  Result := False;
  if (Point <> nil) and (OutPlain <> nil) and IsPointOnCurve(Point) then
  begin
    BigNumberCopy(OutPlain, Point.X);
    Result := True;
  end;
end;

function CnEccDiffieHellmanGenerateOutKey(Ecc: TCnEcc; SelfPrivateKey: TCnEccPrivateKey;
  PublicKey: TCnEccPublicKey): Boolean;
begin
  // PublicKey = SelfPrivateKey * G
  Result := False;
  if (Ecc <> nil) and (SelfPrivateKey <> nil) and not BigNumberIsNegative(SelfPrivateKey) then
  begin
    PublicKey.Assign(Ecc.Generator);
    Ecc.MultiplePoint(SelfPrivateKey, PublicKey);
    Result := True;
  end;
end;

function CnEccDiffieHellmanComputeKey(Ecc: TCnEcc; SelfPrivateKey: TCnEccPrivateKey;
  OtherPublicKey: TCnEccPublicKey; SharedSecretKey: TCnEccPublicKey): Boolean;
begin
  // SecretKey = SelfPrivateKey * OtherPublicKey
  Result := False;
  if (Ecc <> nil) and (SelfPrivateKey <> nil) and not BigNumberIsNegative(SelfPrivateKey) then
  begin
    SharedSecretKey.Assign(OtherPublicKey);
    Ecc.MultiplePoint(SelfPrivateKey, SharedSecretKey);
    Result := True;
  end;
end;

function GetCurveTypeFromOID(Data: PAnsiChar; DataLen: Cardinal): TCnEccCurveType;
var
  P: PByte;
  L: Byte;
begin
  Result := ctCustomized;
  if (Data = nil) or (DataLen < 3) then
    Exit;

  P := PByte(Data);
  if P^ <> CN_BER_TAG_OBJECT_IDENTIFIER then
    Exit;
  Inc(P);

  L := P^;
  if L > EC_CURVE_TYPE_OID_MAX_LENGTH then
    Exit;

  Inc(P);
  if CompareMem(P, @OID_ECPARAM_CURVE_TYPE_SECP256K1[0],
    Min(L, SizeOf(OID_ECPARAM_CURVE_TYPE_SECP256K1))) then
    Result := ctSecp256k1
  else if CompareMem(P, @OID_ECPARAM_CURVE_TYPE_SM2[0],
    Min(L, SizeOf(OID_ECPARAM_CURVE_TYPE_SM2))) then
    Result := ctSM2
  else if CompareMem(P, @OID_ECPARAM_CURVE_TYPE_PRIME256V1[0],
    Min(L, SizeOf(OID_ECPARAM_CURVE_TYPE_PRIME256V1))) then
    Result := ctPrime256v1
end;

// 根据曲线类型返回其 OID 地址与长度，外界使用后无需释放
function GetOIDFromCurveType(Curve: TCnEccCurveType; out OIDAddr: Pointer): Integer;
begin
  Result := 0;
  OIDAddr := nil;

  case Curve of
    ctSecp256k1:
      begin
        OIDAddr := @OID_ECPARAM_CURVE_TYPE_SECP256K1[0];
        Result := SizeOf(OID_ECPARAM_CURVE_TYPE_SECP256K1);
      end;
    ctSM2:
      begin
        OIDAddr := @OID_ECPARAM_CURVE_TYPE_SM2[0];
        Result := SizeOf(OID_ECPARAM_CURVE_TYPE_SM2);
      end;
    ctPrime256v1:
      begin
        OIDAddr := @OID_ECPARAM_CURVE_TYPE_PRIME256V1[0];
        Result := SizeOf(OID_ECPARAM_CURVE_TYPE_PRIME256V1);
      end;
  end;
end;

function ReadEccPublicKeyFromBitStringNode(BitStringNode: TCnBerReadNode; PublicKey: TCnEccPublicKey): Boolean;
var
  B: PByte;
  Len: Integer;
begin
  Result := False;
  if (BitStringNode = nil) or (PublicKey = nil) then
    Exit;

  // PubNode 的 Data 是 BITSTRING，00 04 开头
  // BITSTRING 数据区第一个内容字节是该 BITSTRING 凑成 8 的倍数所缺少的 Bit 数，这里是 0，跳过
  B := BitStringNode.BerDataAddress;
  Inc(B); // 跳过 00，指向压缩模式字节

  if B^ = EC_PUBLICKEY_UNCOMPRESSED then
  begin
    // 未压缩格式，前一半是公钥的 X，后一半是公钥的 Y
    Inc(B);
    Len := (BitStringNode.BerDataLength - 2) div 2;
    PublicKey.X.SetBinary(PAnsiChar(B), Len);
    Inc(B, Len);
    PublicKey.Y.SetBinary(PAnsiChar(B), Len);

    Result := True;
  end
  else if (B^ = EC_PUBLICKEY_COMPRESSED1) or (B^ = EC_PUBLICKEY_COMPRESSED2) then
  begin
    Inc(B);
    // 压缩格式，全是公钥 X
    PublicKey.X.SetBinary(PAnsiChar(B), BitStringNode.BerDataLength - 2);
    PublicKey.Y.SetZero; // Y 先 0，外部再去求解

    Result := True;
  end;
end;

function WriteEccPublicKeyToBitStringNode(Writer: TCnBerWriter;
  ParentNode: TCnBerWriteNode; PublicKey: TCnEccPublicKey): Boolean;
var
  Cnt: Integer;
  B: Byte;
  OP, P: PByte;
begin
  Result := False;
  if (ParentNode = nil) or (PublicKey = nil) then
    Exit;

  Cnt := PublicKey.X.GetBytesCount;
  if not PublicKey.Y.IsZero then
  begin
    Cnt := Cnt + PublicKey.Y.GetBytesCount;
    B := EC_PUBLICKEY_UNCOMPRESSED;
  end
  else
    B := EC_PUBLICKEY_COMPRESSED2;

  OP := GetMemory(Cnt + 1);
  P := OP;
  P^ := B;

  Inc(P);
  PublicKey.X.ToBinary(PAnsiChar(P));
  if B = EC_PUBLICKEY_UNCOMPRESSED then
  begin
    Inc(P, PublicKey.X.GetBytesCount);
    PublicKey.Y.ToBinary(PAnsiChar(P));
  end;
  Writer.AddBasicNode(CN_BER_TAG_BIT_STRING, OP, Cnt + 1, ParentNode);
  FreeMemory(OP);
end;

(*
  SEQUENCE (2 elem)
    SEQUENCE (2 elem)
      OBJECT IDENTIFIER 1.2.840.10045.2.1 ecPublicKey (ANSI X9.62 public key type)
      OBJECT IDENTIFIER 1.3.132.0.10 secp256k1 (SECG (Certicom) named elliptic curve)
    BIT STRING
*)
function CnEccLoadPublicKeyFromPem(const PemFileName: string;
  PublicKey: TCnEccPublicKey; out CurveType: TCnEccCurveType;
  KeyHashMethod: TCnKeyHashMethod; const Password: string): Boolean;
var
  MemStream: TMemoryStream;
  Reader: TCnBerReader;
  Node: TCnBerReadNode;
begin
  Result := False;
  MemStream := nil;
  Reader := nil;

  if PublicKey = nil then
    Exit;

  try
    MemStream := TMemoryStream.Create;
    if LoadPemFileToMemory(PemFileName, PEM_EC_PUBLIC_HEAD, PEM_EC_PUBLIC_TAIL,
      MemStream, Password, KeyHashMethod) then
    begin
      Reader := TCnBerReader.Create(PByte(MemStream.Memory), MemStream.Size);
      Reader.ParseToTree;
      if Reader.TotalCount >= 5 then
      begin
        // 2 要判断是否公钥
        Node := Reader.Items[2];
        if (Node.BerLength <> SizeOf(OID_EC_PUBLIC_KEY)) or not CompareMem(@OID_EC_PUBLIC_KEY[0],
          Node.BerAddress, Node.BerLength) then
          Exit;

        // 3 是曲线类型
        Node := Reader.Items[3];
        CurveType := GetCurveTypeFromOID(Node.BerDataAddress, Node.BerDataLength);

        // 读 4 里的公钥
        Result := ReadEccPublicKeyFromBitStringNode(Reader.Items[4], PublicKey);
      end;
    end;
  finally
    MemStream.Free;
    Reader.Free;
  end;
end;

(*
   ECPrivateKey ::= SEQUENCE {
     version        INTEGER { ecPrivkeyVer1(1) } (ecPrivkeyVer1),
     privateKey     OCTET STRING,
     parameters [0] ECParameters {{ NamedCurve }} OPTIONAL,
     publicKey  [1] BIT STRING OPTIONAL
   }

  SEQUENCE (4 elem)
    INTEGER 1
    OCTET STRING (32 byte) 10C8813CC012D659A282B261E86D0440848DB246A077C427203F92FD90B3CD77
    [0] (1 elem)
      OBJECT IDENTIFIER 1.3.132.0.10 secp256k1 (SECG (Certicom) named elliptic curve)
    [1] (1 elem)
      BIT STRING
*)
function CnEccLoadKeysFromPem(const PemFileName: string; PrivateKey: TCnEccPrivateKey;
  PublicKey: TCnEccPublicKey; out CurveType: TCnEccCurveType;
  KeyHashMethod: TCnKeyHashMethod = ckhMd5; const Password: string = ''): Boolean;
var
  MemStream: TMemoryStream;
  Reader: TCnBerReader;
  Node: TCnBerReadNode;
  CurveType2: TCnEccCurveType;
begin
  Result := False;
  MemStream := nil;
  Reader := nil;

  try
    MemStream := TMemoryStream.Create;
    if LoadPemFileToMemory(PemFileName, PEM_EC_PARAM_HEAD, PEM_EC_PARAM_TAIL,
      MemStream, Password, KeyHashMethod) then
      // 读 ECPARAM 也即椭圆曲线类型
      CurveType := GetCurveTypeFromOID(PAnsiChar(MemStream.Memory), MemStream.Size);

    if LoadPemFileToMemory(PemFileName, PEM_EC_PRIVATE_HEAD, PEM_EC_PRIVATE_TAIL,
      MemStream, Password, KeyHashMethod) then
    begin
      Reader := TCnBerReader.Create(PByte(MemStream.Memory), MemStream.Size);
      Reader.ParseToTree;
      if Reader.TotalCount >= 7 then
      begin
        Node := Reader.Items[1]; // 0 是整个 Sequence，1 是 Version
        if Node.AsByte = 1 then  // 只支持版本 1
        begin
          // 2 是私钥
          if PrivateKey <> nil then
            PutIndexedBigIntegerToBigInt(Reader.Items[2], PrivateKey);

          // 4 又是曲线类型
          Node := Reader.Items[4];
          CurveType2 := GetCurveTypeFromOID(Node.BerAddress, Node.BerLength);
          if (CurveType <> ctCustomized) and (CurveType2 <> CurveType) then
            Exit;

          CurveType := CurveType2; // 如果俩读出不一样，以第二个为准

          // 读 6 里的公钥
          Result := ReadEccPublicKeyFromBitStringNode(Reader.Items[6], PublicKey);
        end;
      end;
    end;
  finally
    MemStream.Free;
    Reader.Free;
  end;
end;

function CnEccSaveKeysToPem(const PemFileName: string; PrivateKey: TCnEccPrivateKey;
  PublicKey: TCnEccPublicKey; CurveType: TCnEccCurveType;
  KeyEncryptMethod: TCnKeyEncryptMethod = ckeNone;
  KeyHashMethod: TCnKeyHashMethod = ckhMd5; const Password: string = ''): Boolean;
var
  Root, Node: TCnBerWriteNode;
  Writer: TCnBerWriter;
  Mem: TMemoryStream;
  OIDPtr: Pointer;
  OIDLen: Integer;
  B: Byte;
begin
  Result := False;
  if (PrivateKey = nil) or (PublicKey = nil) then
    Exit;

  OIDLen := GetOIDFromCurveType(CurveType, OIDPtr);
  if (OIDPtr = nil) or (OIDLen <= 0) then
    Exit;

  Mem := nil;
  Writer := nil;

  try
    Mem := TMemoryStream.Create;
    if (KeyEncryptMethod = ckeNone) or (Password = '') then
    begin
      // 不加密，分两段，第一段手工写
      B := CN_BER_TAG_OBJECT_IDENTIFIER;
      Mem.Write(B, 1);
      B := OIDLen;
      Mem.Write(B, 1);

      Mem.Write(OIDPtr^, OIDLen);
      if not SaveMemoryToPemFile(PemFileName, PEM_EC_PARAM_HEAD, PEM_EC_PARAM_TAIL, Mem) then
        Exit;

      Mem.Clear;
    end;

    Writer := TCnBerWriter.Create;

    // 第二段组树
    Root := Writer.AddContainerNode(CN_BER_TAG_SEQUENCE);
    B := 1;
    Writer.AddBasicNode(CN_BER_TAG_INTEGER, @B, 1, Root); // 写 Version 1
    AddBigNumberToWriter(Writer, PrivateKey, Root);       // 写私钥

    Node := Writer.AddContainerNode(CN_BER_TAG_RESERVED, Root);
    Node.BerTypeMask := ECC_PRIVATEKEY_TYPE_MASK;
    Writer.AddBasicNode(CN_BER_TAG_OBJECT_IDENTIFIER, PByte(OIDPtr), OIDLen, Node);

    Node := Writer.AddContainerNode(CN_BER_TAG_BOOLEAN, Root); // 居然要用 BOOLEAN 才行
    Node.BerTypeMask := ECC_PRIVATEKEY_TYPE_MASK;

    WriteEccPublicKeyToBitStringNode(Writer, Node, PublicKey);
    Writer.SaveToStream(Mem);
    Result := SaveMemoryToPemFile(PemFileName, PEM_EC_PRIVATE_HEAD, PEM_EC_PRIVATE_TAIL, Mem,
      KeyEncryptMethod, KeyHashMethod, Password, True);
  finally
    Mem.Free;
    Writer.Free;
  end;
end;

function CnEccSavePublicKeyToPem(const PemFileName: string;
  PublicKey: TCnEccPublicKey; CurveType: TCnEccCurveType;
  KeyType: TCnEccKeyType = cktPKCS1; KeyEncryptMethod: TCnKeyEncryptMethod = ckeNone;
  KeyHashMethod: TCnKeyHashMethod = ckhMd5; const Password: string = ''): Boolean;
var
  Root, Node: TCnBerWriteNode;
  Writer: TCnBerWriter;
  Mem: TMemoryStream;
  OIDPtr: Pointer;
  OIDLen: Integer;
begin
  Result := False;
  if (PublicKey = nil) or (PublicKey.X.IsZero) then
    Exit;

  OIDLen := GetOIDFromCurveType(CurveType, OIDPtr);
  if (OIDPtr = nil) or (OIDLen <= 0) then
    Exit;

  Mem := nil;
  Writer := nil;

  try
    Writer := TCnBerWriter.Create;
    Root := Writer.AddContainerNode(CN_BER_TAG_SEQUENCE);
    Node := Writer.AddContainerNode(CN_BER_TAG_SEQUENCE, Root);

    // 给 Node 加 ECPublicKey 与 曲线类型的 ObjectIdentifier
    Writer.AddBasicNode(CN_BER_TAG_OBJECT_IDENTIFIER, @OID_EC_PUBLIC_KEY[0],
      SizeOf(OID_EC_PUBLIC_KEY), Node);
    Writer.AddBasicNode(CN_BER_TAG_OBJECT_IDENTIFIER, OIDPtr, OIDLen, Node);
    WriteEccPublicKeyToBitStringNode(Writer, Node, PublicKey);

    Mem := TMemoryStream.Create;
    Writer.SaveToStream(Mem);

    Result := SaveMemoryToPemFile(PemFileName, PEM_EC_PUBLIC_HEAD, PEM_EC_PUBLIC_TAIL, Mem,
      KeyEncryptMethod, KeyHashMethod, Password);
  finally
    Mem.Free;
    Writer.Free;
  end;
end;

// ECC 签名与验证

// 根据指定数字摘要算法计算指定流的二进制散列值并写入 Stream
function CalcDigestStream(InStream: TStream; SignType: TCnEccSignDigestType;
  outStream: TStream): Boolean;
var
  Md5: TMD5Digest;
  Sha1: TSHA1Digest;
  Sha256: TSHA256Digest;
  Sm3Dig: TSM3Digest;
begin
  Result := False;
  case SignType of
    esdtMD5:
      begin
        Md5 := MD5Stream(InStream);
        outStream.Write(Md5, SizeOf(TMD5Digest));
        Result := True;
      end;
    esdtSHA1:
      begin
        Sha1 := SHA1Stream(InStream);
        outStream.Write(Sha1, SizeOf(TSHA1Digest));
        Result := True;
      end;
    esdtSHA256:
      begin
        Sha256 := SHA256Stream(InStream);
        outStream.Write(Sha256, SizeOf(TSHA256Digest));
        Result := True;
      end;
    esdtSM3:
      begin
        Sm3Dig := SM3Stream(InStream);
        outStream.Write(Sm3Dig, SizeOf(TSM3Digest));
        Result := True;
      end;
  end;
end;

// 根据指定数字摘要算法计算文件的二进制散列值并写入 Stream
function CalcDigestFile(const FileName: string; SignType: TCnEccSignDigestType;
  outStream: TStream): Boolean;
var
  Md5: TMD5Digest;
  Sha1: TSHA1Digest;
  Sha256: TSHA256Digest;
  Sm3Dig: TSM3Digest;
begin
  Result := False;
  case SignType of
    esdtMD5:
      begin
        Md5 := MD5File(FileName);
        outStream.Write(Md5, SizeOf(TMD5Digest));
        Result := True;
      end;
    esdtSHA1:
      begin
        Sha1 := SHA1File(FileName);
        outStream.Write(Sha1, SizeOf(TSHA1Digest));
        Result := True;
      end;
    esdtSHA256:
      begin
        Sha256 := SHA256File(FileName);
        outStream.Write(Sha256, SizeOf(TSHA256Digest));
        Result := True;
      end;
    esdtSM3:
      begin
        Sm3Dig := SM3File(FileName);
        outStream.Write(Sm3Dig, SizeOf(TSM3Digest));
        Result := True;
      end;
  end;
end;

{
  按维基百科上说明的 ECDSA 算法进行签名：
  https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm
}
function EccSignValue(Ecc: TCnEcc; PrivateKey: TCnEccPrivateKey; InE, OutR, OutS: TCnBigNumber): Boolean;
var
  K, X, KInv: TCnBigNumber;
  P: TCnEccPoint;
begin
  Result := False;
  BuildShortXValue(InE, Ecc.Order); // InE 现在是 z

  K := nil;
  X := nil;
  KInv := nil;
  P := nil;

  try
    K := TCnBigNumber.Create;
    KInv := TCnBigNumber.Create;
    X := TCnBigNumber.Create;
    P := TCnEccPoint.Create;

    while True do
    begin
      if not BigNumberRandRange(K, Ecc.Order) then // 生成重要的随机 K
        Exit;

      // K.SetHex('9E56F509196784D963D1C0A401510EE7ADA3DCC5DEE04B154BF61AF1D5A6DECE');   // 指定随机值时做测试

      P.Assign(Ecc.Generator);
      Ecc.MultiplePoint(K, P);

      if not BigNumberNonNegativeMod(OutR, P.X, Ecc.Order) then
        Exit;

      if OutR.IsZero then
        Continue;
      // 算出了签名的一部分 R

      if not BigNumberMul(X, PrivateKey, OutR) then   // X <= r * PrivateKey
        Exit;
      if not BigNumberAdd(X, X, InE) then             // X <= X + z
        Exit;
      BigNumberModularInverse(KInv, K, Ecc.Order);
      if not BigNumberMul(X, KInv, X) then            // X <= K^-1 * X
        Exit;
      if not BigNumberNonNegativeMod(OutS, X, Ecc.Order) then  // OutS <= K^-1 * (z + r * PrivateKey) mod N
        Exit;

      if OutS.IsZero then
        Continue;

      Break;
    end;
    Result := True;
  finally
    P.Free;
    KInv.Free;
    X.Free;
    K.Free;
  end;
end;

function CnEccSignFile(const InFileName, OutSignFileName: string; Ecc: TCnEcc;
  PrivateKey: TCnEccPrivateKey; SignType: TCnEccSignDigestType = esdtMD5): Boolean;
var
  Stream: TMemoryStream;
  E, R, S: TCnBigNumber;
  Writer: TCnBerWriter;
  Root: TCnBerWriteNode;
begin
  Result := False;
  Stream := nil;
  Writer := nil;
  E := nil;
  R := nil;
  S := nil;

  try
    Stream := TMemoryStream.Create;

    if not CalcDigestFile(InFileName, SignType, Stream) then // 计算文件的散列值
      Exit;
    E := TCnBigNumber.Create;
    E.SetBinary(Stream.Memory, Stream.Size);

    R := TCnBigNumber.Create;
    S := TCnBigNumber.Create;

    if EccSignValue(Ecc, PrivateKey, E, R, S) then
    begin
      // 然后按格式进行 BER 编码
      Writer := TCnBerWriter.Create;
      Root := Writer.AddContainerNode(CN_BER_TAG_SEQUENCE);
      AddBigNumberToWriter(Writer, R, Root);
      AddBigNumberToWriter(Writer, S, Root);

      Writer.SaveToFile(OutSignFileName);
      Result := True;
    end;
  finally
    Stream.Free;
    E.Free;
    R.Free;
    S.Free;
    Writer.Free;
  end;
end;

function CnEccSignFile(const InFileName, OutSignFileName: string; CurveType: TCnEccCurveType;
  PrivateKey: TCnEccPrivateKey; SignType: TCnEccSignDigestType = esdtMD5): Boolean;
var
  Ecc: TCnEcc;
begin
  if CurveType = ctCustomized then
    raise ECnEccException.Create(SCnEccErrorCurveType);

  Ecc := TCnEcc.Create(CurveType);
  try
    Result := CnEccSignFile(InFileName, OutSignFileName, Ecc, PrivateKey, SignType);
  finally
    Ecc.Free;
  end;
end;

{
  按维基百科上说明的 ECDSA 算法进行签名验证：
  https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm
}
function EccVerifyValue(Ecc: TCnEcc; PublicKey: TCnEccPublicKey; InE, InR, InS: TCnBigNumber): Boolean;
var
  U1, U2, SInv: TCnBigNumber;
  P1, P2: TCnEccPoint;
begin
  Result := False;
  if not CheckEccPublicKey(Ecc, PublicKey) then
    Exit;

  BuildShortXValue(InE, Ecc.Order); // InE is z

  U1 := nil;
  U2 := nil;
  P1 := nil;
  P2 := nil;
  SInv := nil;

  try
    SInv := TCnBigNumber.Create;
    BigNumberModularInverse(SInv, InS, Ecc.Order);
    U1 := TCnBigNumber.Create;
    if not BigNumberMul(U1, InE, SInv) then
      Exit;
    if not BigNumberNonNegativeMod(U1, U1, Ecc.Order) then // u1 = (z * s^-1) mod N
      Exit;

    U2 := TCnBigNumber.Create;
    if not BigNumberMul(U2, InR, SInv) then
      Exit;
    if not BigNumberNonNegativeMod(U1, U1, Ecc.Order) then // u2 = (r * s^-1) mod N
      Exit;

    P1 := TCnEccPoint.Create;
    P1.Assign(Ecc.Generator);
    Ecc.MultiplePoint(U1, P1);

    P2 := TCnEccPoint.Create;
    P2.Assign(PublicKey);
    Ecc.MultiplePoint(U2, P2);
    Ecc.PointAddPoint(P1, P2, P1);  // 计算 u1 * G + u2 * PublicKey 点
    if P1.IsZero then
      Exit;

    if not BigNumberNonNegativeMod(P1.X, P1.X, Ecc.Order) then // 计算 P1.X mod N
      Exit;

    if not BigNumberNonNegativeMod(P1.Y, InR, Ecc.Order) then  // 计算 r mod N
      Exit;

    Result := BigNumberCompare(P1.X, P1.Y) = 0;
  finally
    SInv.Free;
    P2.Free;
    P1.Free;
    U2.Free;
    U1.Free;
  end;
end;

function CnEccVerifyFile(const InFileName, InSignFileName: string; Ecc: TCnEcc;
  PublicKey: TCnEccPublicKey; SignType: TCnEccSignDigestType = esdtMD5): Boolean;
var
  Stream: TMemoryStream;
  E, R, S: TCnBigNumber;
  Reader: TCnBerReader;
begin
  Result := False;
  Stream := nil;
  Reader := nil;
  E := nil;
  R := nil;
  S := nil;

  try
    Stream := TMemoryStream.Create;

    if not CalcDigestFile(InFileName, SignType, Stream) then // 计算文件的散列值
      Exit;

    E := TCnBigNumber.Create;
    E.SetBinary(Stream.Memory, Stream.Size);

    Stream.Clear;
    Stream.LoadFromFile(InSignFileName);
    Reader := TCnBerReader.Create(Stream.Memory, Stream.Size);
    Reader.ParseToTree;

    if Reader.TotalCount <> 3 then
      Exit;

    R := TCnBigNumber.Create;
    S := TCnBigNumber.Create;
    PutIndexedBigIntegerToBigInt(Reader.Items[1], R);
    PutIndexedBigIntegerToBigInt(Reader.Items[2], S);

    Result := EccVerifyValue(Ecc, PublicKey, E, R, S);
  finally
    Stream.Free;
    Reader.Free;
    E.Free;
    R.Free;
    S.Free;
  end;
end;

function CnEccVerifyFile(const InFileName, InSignFileName: string; CurveType: TCnEccCurveType;
  PublicKey: TCnEccPublicKey; SignType: TCnEccSignDigestType = esdtMD5): Boolean;
var
  Ecc: TCnEcc;
begin
  if CurveType = ctCustomized then
    raise ECnEccException.Create(SCnEccErrorCurveType);

  Ecc := TCnEcc.Create(CurveType);
  try
    Result := CnEccVerifyFile(InFileName, InSignFileName, Ecc, PublicKey, SignType);
  finally
    Ecc.Free;
  end;
end;

{
  ECC 签名输出的 BER 格式如下，直接存成二进制文件即可
  SEQUENCE (2 elem)
    INTEGER r
    INTEGER s
}
function CnEccSignStream(InStream: TMemoryStream; OutSignStream: TMemoryStream;
  Ecc: TCnEcc; PrivateKey: TCnEccPrivateKey;
  SignType: TCnEccSignDigestType = esdtMD5): Boolean;
var
  Stream: TMemoryStream;
  E, R, S: TCnBigNumber;
  Writer: TCnBerWriter;
  Root: TCnBerWriteNode;
begin
  Result := False;
  Stream := nil;
  Writer := nil;
  E := nil;
  R := nil;
  S := nil;

  try
    Stream := TMemoryStream.Create;

    if not CalcDigestStream(InStream, SignType, Stream) then // 计算流的散列值
      Exit;
    E := TCnBigNumber.Create;
    E.SetBinary(Stream.Memory, Stream.Size);

    R := TCnBigNumber.Create;
    S := TCnBigNumber.Create;

    if EccSignValue(Ecc, PrivateKey, E, R, S) then
    begin
      // 然后按格式进行 BER 编码
      Writer := TCnBerWriter.Create;
      Root := Writer.AddContainerNode(CN_BER_TAG_SEQUENCE);
      AddBigNumberToWriter(Writer, R, Root);
      AddBigNumberToWriter(Writer, S, Root);

      Writer.SaveToStream(OutSignStream);
      Result := True;
    end;
  finally
    Stream.Free;
    E.Free;
    R.Free;
    S.Free;
    Writer.Free;
  end;
end;

function CnEccSignStream(InStream: TMemoryStream; OutSignStream: TMemoryStream;
  CurveType: TCnEccCurveType; PrivateKey: TCnEccPrivateKey;
  SignType: TCnEccSignDigestType = esdtMD5): Boolean;
var
  Ecc: TCnEcc;
begin
  if CurveType = ctCustomized then
    raise ECnEccException.Create(SCnEccErrorCurveType);

  Ecc := TCnEcc.Create(CurveType);
  try
    Result := CnEccSignStream(InStream, OutSignStream, Ecc, PrivateKey, SignType);
  finally
    Ecc.Free;
  end;
end;

function CnEccVerifyStream(InStream: TMemoryStream; InSignStream: TMemoryStream;
  Ecc: TCnEcc; PublicKey: TCnEccPublicKey;
  SignType: TCnEccSignDigestType = esdtMD5): Boolean;
var
  Stream: TMemoryStream;
  E, R, S: TCnBigNumber;
  Reader: TCnBerReader;
begin
  Result := False;
  Stream := nil;
  Reader := nil;
  E := nil;
  R := nil;
  S := nil;

  try
    Stream := TMemoryStream.Create;

    if not CalcDigestStream(InStream, SignType, Stream) then // 计算流的散列值
      Exit;

    E := TCnBigNumber.Create;
    E.SetBinary(Stream.Memory, Stream.Size);

    Stream.Clear;
    Stream.LoadFromStream(InSignStream);
    Reader := TCnBerReader.Create(Stream.Memory, Stream.Size);
    Reader.ParseToTree;

    if Reader.TotalCount <> 3 then
      Exit;

    R := TCnBigNumber.Create;
    S := TCnBigNumber.Create;
    PutIndexedBigIntegerToBigInt(Reader.Items[1], R);
    PutIndexedBigIntegerToBigInt(Reader.Items[2], S);

    Result := EccVerifyValue(Ecc, PublicKey, E, R, S);
  finally
    Stream.Free;
    Reader.Free;
    E.Free;
    R.Free;
    S.Free;
  end;
end;

function CnEccVerifyStream(InStream: TMemoryStream; InSignStream: TMemoryStream;
  CurveType: TCnEccCurveType; PublicKey: TCnEccPublicKey;
  SignType: TCnEccSignDigestType = esdtMD5): Boolean;
var
  Ecc: TCnEcc;
begin
  if CurveType = ctCustomized then
    raise ECnEccException.Create(SCnEccErrorCurveType);

  Ecc := TCnEcc.Create(CurveType);
  try
    Result := CnEccVerifyStream(InStream, InSignStream, Ecc, PublicKey, SignType);
  finally
    Ecc.Free;
  end;
end;

function CheckEccPublicKey(Ecc: TCnEcc; PublicKey: TCnEccPublicKey): Boolean;
var
  P: TCnEccPoint;
begin
  Result := False;
  if (Ecc <> nil) and (PublicKey <> nil) then
  begin
    if PublicKey.IsZero then
      Exit;
    if not Ecc.IsPointOnCurve(PublicKey) then
      Exit;

    P := TCnEccPoint.Create;
    try
      P.Assign(PublicKey);
      Ecc.MultiplePoint(Ecc.Order, P);
      Result := P.IsZero;
    finally
      P.Free;
    end;
  end;
end;

function GetEccDigestNameFromSignDigestType(Digest: TCnEccSignDigestType): string;
begin
  case Digest of
    esdtMD5: Result := 'MD5';
    esdtSHA1: Result := 'SHA1';
    esdtSHA256: Result := 'SHA256';
    esdtSM3: Result := 'SM3';
  else
    Result := '<Unknown>';
  end;
end;

{ TCnInt64PolynomialEccPoint }

procedure TCnInt64PolynomialEccPoint.Assign(Source: TPersistent);
begin
  if Source is TCnInt64PolynomialEccPoint then
  begin
    Int64PolynomialCopy(FX, (Source as TCnInt64PolynomialEccPoint).X);
    Int64PolynomialCopy(FY, (Source as TCnInt64PolynomialEccPoint).Y);
  end
  else
    inherited;
end;

constructor TCnInt64PolynomialEccPoint.Create;
begin
  inherited;
  FX := TCnInt64Polynomial.Create;
  FY := TCnInt64Polynomial.Create;
end;

constructor TCnInt64PolynomialEccPoint.Create(
  const XLowToHighCoefficients, YLowToHighCoefficients: array of const);
begin
  Create;
  FX.SetCoefficents(XLowToHighCoefficients);
  FY.SetCoefficents(YLowToHighCoefficients);
end;

destructor TCnInt64PolynomialEccPoint.Destroy;
begin
  FY.Free;
  FX.Free;
  inherited;
end;

function TCnInt64PolynomialEccPoint.IsZero: Boolean;
begin
  Result := FX.IsZero and FY.IsZero;
end;

procedure TCnInt64PolynomialEccPoint.SetX(
  const Value: TCnInt64Polynomial);
begin
  if Value <> nil then
    Int64PolynomialCopy(FX, Value);
end;

procedure TCnInt64PolynomialEccPoint.SetY(
  const Value: TCnInt64Polynomial);
begin
  if Value <> nil then
    Int64PolynomialCopy(FY, Value);
end;

procedure TCnInt64PolynomialEccPoint.SetZero;
begin
  FX.SetZero;
  FY.SetZero;
end;

function TCnInt64PolynomialEccPoint.ToString: string;
begin
  Result := CnInt64PolynomialEccPointToString(Self);
end;

function CnInt64PolynomialEccPointToString(const P: TCnInt64PolynomialEccPoint): string;
begin
  Result := Format('%s; %s', [P.X.ToString, P.Y.ToString]);
end;

function CnInt64PolynomialEccPointsEqual(P1, P2: TCnInt64PolynomialEccPoint): Boolean;
begin
  Result := Int64PolynomialEqual(P1.X, P2.X) and Int64PolynomialEqual(P1.Y, P2.Y);
end;

{ TCnInt64PolynomialEcc }

constructor TCnInt64PolynomialEcc.Create(A, B, FieldPrime: Int64; Ext: Integer;
  GX, GY: array of const; Order: Int64; PrimitivePolynomial: array of const);
begin
  inherited Create;

  // 由外界保证 Order 为素数
  if not CnInt64IsPrime(FieldPrime) then // or not CnInt64IsPrime(Order) then
    raise ECnEccException.Create('Infinite Field must be a Prime Number.');

  // 扩域次数得大于 1
  if Ext <= 1 then
    raise ECnEccException.Create('Field Extension must > 1.');

  // 要确保 4*a^3+27*b^2 <> 0
  if 4 * A * A * A + 27 * B * B = 0 then
    raise ECnEccException.Create('Error: 4 * A^3 + 27 * B^2 = 0');

  FCoefficientA := A;
  FCoefficientB := B;
  FFiniteFieldSize := FieldPrime;
  FExtension := Ext;

  FGenerator := TCnInt64PolynomialEccPoint.Create;
  FGenerator.X.SetCoefficents(GX);
  FGenerator.Y.SetCoefficents(GY);

  FOrder := Order;

  FPrimitive := TCnInt64Polynomial.Create;
  FPrimitive.SetCoefficents(PrimitivePolynomial);
end;

destructor TCnInt64PolynomialEcc.Destroy;
begin
  FPrimitive.Free;
  FGenerator.Free;
  inherited;
end;

function TCnInt64PolynomialEcc.DivisionPolynomial(Degree: Integer;
  outDivisionPolynomial: TCnInt64Polynomial): Boolean;
begin
  Result := Int64PolynomialGaloisCalcDivisionPolynomial(FCoefficientA, FCoefficientB,
    Degree, outDivisionPolynomial, FFiniteFieldSize);
end;

function TCnInt64PolynomialEcc.IsPointOnCurve(
  P: TCnInt64PolynomialEccPoint): Boolean;
var
  X, Y: TCnInt64Polynomial;
begin
  // 计算 (Y^2 - X^3 - A*X - B) mod primitive （多项式系数运算要 mod p）是否等于 0 多项式
  Result := False;
  if P <> nil then
  begin
    X := nil;
    Y := nil;

    try
      X := FEccInt64PolynomialPool.Obtain;
      Y := FEccInt64PolynomialPool.Obtain;

      Int64PolynomialCopy(Y, P.Y);
      Int64PolynomialGaloisMul(Y, Y, Y, FFiniteFieldSize, FPrimitive);

      Int64PolynomialCopy(X, P.X);
      Int64PolynomialGaloisPower(X, X, 3, FFiniteFieldSize, FPrimitive);

      Int64PolynomialGaloisSub(Y, Y, X, FFiniteFieldSize, FPrimitive);                // Y := Y^2 - X^3

      Int64PolynomialCopy(X, P.X);
      Int64PolynomialMulWord(X, FCoefficientA);
      Int64PolynomialAddWord(X, FCoefficientB);   // X := A*X + B
      Int64PolynomialNonNegativeModWord(X, FFiniteFieldSize);

      Int64PolynomialGaloisSub(Y, Y, X, FFiniteFieldSize, FPrimitive);
      Int64PolynomialGaloisMod(Y, Y, FPrimitive, FFiniteFieldSize);

      Result := Y.IsZero;
    finally
      FEccInt64PolynomialPool.Recycle(Y);
      FEccInt64PolynomialPool.Recycle(X);
    end;
  end;
end;

class function TCnInt64PolynomialEcc.IsPointOnCurve2(PX,
  PY: TCnInt64Polynomial; A, B, APrime: Int64;
  APrimitive: TCnInt64Polynomial): Boolean;
var
  X, Y: TCnInt64Polynomial;
begin
  // 计算 (Y^2 - X^3 - A*X - B) mod primitive （多项式系数运算要 mod p）是否等于 0 多项式
  X := nil;
  Y := nil;

  try
    X := FEccInt64PolynomialPool.Obtain;
    Y := FEccInt64PolynomialPool.Obtain;

    Int64PolynomialCopy(Y, PY);
    Int64PolynomialGaloisMul(Y, Y, Y, APrime, APrimitive);

    Int64PolynomialCopy(X, PX);
    Int64PolynomialGaloisPower(X, X, 3, APrime, APrimitive);

    Int64PolynomialGaloisSub(Y, Y, X, APrime, APrimitive);                // Y := Y^2 - X^3

    Int64PolynomialCopy(X, PX);
    Int64PolynomialMulWord(X, A);
    Int64PolynomialAddWord(X, B);   // X := A*X + B
    Int64PolynomialNonNegativeModWord(X, APrime);

    Int64PolynomialGaloisSub(Y, Y, X, APrime, APrimitive);
    Int64PolynomialGaloisMod(Y, Y, APrimitive, APrime);

    Result := Y.IsZero;
  finally
    FEccInt64PolynomialPool.Recycle(Y);
    FEccInt64PolynomialPool.Recycle(X);
  end;
end;

class function TCnInt64PolynomialEcc.IsRationalPointOnCurve(PX,
  PY: TCnInt64RationalPolynomial; A, B, APrime: Int64): Boolean;
var
  Y2, T1: TCnInt64Polynomial;
  RL, RR, T2: TCnInt64RationalPolynomial;
begin
  // 计算 PY^2 * (x^3 + Ax + B) 是否等于 PX^3 + A * PX + B，系数均 mod APrime
  Y2 := nil;
  T1 := nil;
  T2 := nil;
  RL := nil;
  RR := nil;

  try
    Y2 := FEccInt64PolynomialPool.Obtain;
    Y2.SetCoefficents([B, A, 0, 1]);

    RL := TCnInt64RationalPolynomial.Create;
    Int64RationalPolynomialGaloisMul(PY, PY, RL, APrime);
    Int64RationalPolynomialGaloisMul(RL, Y2, RL, APrime);  // 得到等号左边的值

    RR := TCnInt64RationalPolynomial.Create;
    Int64RationalPolynomialGaloisMul(PX, PX, RR, APrime);
    Int64RationalPolynomialGaloisMul(RR, PX, RR, APrime);  // 得到 PX^3
    
    T1 := FEccInt64PolynomialPool.Obtain;
    T1.SetCoefficents([A]);

    T2 := TCnInt64RationalPolynomial.Create;
    Int64RationalPolynomialGaloisMul(PX, T1, T2, APrime);  // T2 得到 A * PX

    T1.SetCoefficents([B]);
    Int64RationalPolynomialGaloisAdd(T2, T1, T2, APrime);  // T2 得到 A * PX + B

    Int64RationalPolynomialGaloisAdd(T2, RR, RR, APrime);  // RR 得到 PX^3 + A * PX + B

    Result := Int64RationalPolynomialEqual(RL, RR);       // 比较是否相等
  finally
    FEccInt64PolynomialPool.Recycle(Y2);
    FEccInt64PolynomialPool.Recycle(T1);
    T2.Free;
    RL.Free;
    RR.Free;
  end;
end;

procedure TCnInt64PolynomialEcc.MultiplePoint(K: Integer;
  Point: TCnInt64PolynomialEccPoint);
var
  E, R: TCnInt64PolynomialEccPoint;
begin
  if K = 0 then
  begin
    Point.SetZero;
    Exit;
  end
  else if K < 0 then
  begin
    K := -K;
    PointInverse(Point);
  end;

  R := nil;
  E := nil;

  try
    R := TCnInt64PolynomialEccPoint.Create;
    E := TCnInt64PolynomialEccPoint.Create;

    R.SetZero;
    E.Assign(Point);

    while K <> 0 do
    begin
      if (K and 1) <> 0 then
        PointAddPoint(R, E, R);

      PointAddPoint(E, E, E);
      K := K shr 1;
    end;

    Point.Assign(R);
  finally
    R.Free;
    E.Free;
  end;
end;

//class procedure TCnInt64PolynomialEcc.MultiplePoint1(K: Integer; PX,
//  PY: TCnInt64Polynomial; A, B, APrime: Int64;
//  APrimitive: TCnInt64Polynomial);
//var
//  EX, EY, RX, RY, SX, SY: TCnInt64Polynomial;
//begin
//  if K = 0 then
//  begin
//    PX.SetZero;
//    PY.SetZero;
//    Exit;
//  end
//  else if K < 0 then
//    raise ECnEccException.Create('Negative Multiple NOT Support');
//
//  EX := nil;
//  EY := nil;
//  RX := nil;
//  RY := nil;
//  SX := nil;
//  SY := nil;
//
//  try
//    EX := FEccInt64PolynomialPool.Obtain;
//    EY := FEccInt64PolynomialPool.Obtain;
//    RX := FEccInt64PolynomialPool.Obtain;
//    RY := FEccInt64PolynomialPool.Obtain;
//    SX := FEccInt64PolynomialPool.Obtain;
//    SY := FEccInt64PolynomialPool.Obtain;
//
//    RX.SetZero;
//    RY.SetZero;
//
//    Int64PolynomialCopy(EX, PX);
//    Int64PolynomialCopy(EY, PY);
//
//    while K <> 0 do
//    begin
//      if (K and 1) <> 0 then
//      begin
//        PointAddPoint1(RX, RY, EX, EY, SX, SY, A, B, APrime, APrimitive);
//        Int64PolynomialCopy(RX, SX);
//        Int64PolynomialCopy(RY, SY);
//      end;
//
//      PointAddPoint1(EX, EY, EX, EY, SX, SY, A, B, APrime, APrimitive);
//      Int64PolynomialCopy(EX, SX);
//      Int64PolynomialCopy(EY, SY);
//
//      K := K shr 1;
//    end;
//
//    Int64PolynomialCopy(PX, RX);
//    Int64PolynomialCopy(PY, RY);
//  finally
//    FEccInt64PolynomialPool.Recycle(EX);
//    FEccInt64PolynomialPool.Recycle(EY);
//    FEccInt64PolynomialPool.Recycle(RX);
//    FEccInt64PolynomialPool.Recycle(RY);
//    FEccInt64PolynomialPool.Recycle(SX);
//    FEccInt64PolynomialPool.Recycle(SY);
//  end;
//end;

procedure TCnInt64PolynomialEcc.PointAddPoint(P, Q,
  Sum: TCnInt64PolynomialEccPoint);
var
  K, X, Y, T: TCnInt64Polynomial;
begin
  K := nil;
  X := nil;
  Y := nil;
  T := nil;

  try
    if P.IsZero then
    begin
      Sum.Assign(Q);
      Exit;
    end
    else if Q.IsZero then
    begin
      Sum.Assign(P);
      Exit;
    end
    else if Int64PolynomialEqual(P.X, Q.X) and Int64PolynomialEqual(P.Y, Q.Y) then
    begin
      // 俩加数是同一个点，切线斜率为两边求导，3 * X^2 + A / (2 * Y) 但如 Y = 0 则直接是无限远 0。
      X := FEccInt64PolynomialPool.Obtain;
      Y := FEccInt64PolynomialPool.Obtain;

      // X := 3 * P.X * P.X + FCoefficientA
      Int64PolynomialGaloisMul(X, P.X, P.X, FFiniteFieldSize, FPrimitive);
      Int64PolynomialGaloisMulWord(X, 3, FFiniteFieldSize);
      Int64PolynomialGaloisAddWord(X, FCoefficientA, FFiniteFieldSize);

      // Y := 2 * P.Y;
      Int64PolynomialCopy(Y, P.Y);
      Int64PolynomialGaloisMulWord(Y, 2, FFiniteFieldSize);

      if Y.IsZero then
      begin
        Sum.X.SetZero;
        Sum.Y.SetZero;
      end;

      // Y := Y^-1
      T := FEccInt64PolynomialPool.Obtain;
      Int64PolynomialCopy(T, Y);
      Int64PolynomialGaloisModularInverse(Y, T, FPrimitive, FFiniteFieldSize);

      // K := X * Y mod FFiniteFieldSize;
      K := FEccInt64PolynomialPool.Obtain;
      Int64PolynomialGaloisMul(K, X, Y, FFiniteFieldSize, FPrimitive);
      // 得到切线斜率 K
    end
    else // 是不同点
    begin
      if Int64PolynomialEqual(P.X, Q.X) then // 如果 X 相等，要判断 Y 是不是互反，是则和为 0，不是则挂了
      begin
        T := FEccInt64PolynomialPool.Obtain;
        Int64PolynomialGaloisAdd(T, P.Y, Q.Y, FFiniteFieldSize);
        if T.IsZero then
          Sum.SetZero
        else
          raise ECnEccException.CreateFmt('Can NOT Calucate %s,%s + %s,%s',
            [P.X.ToString, P.Y.ToString, Q.X.ToString, Q.Y.ToString]);

        Exit;
      end;

      // 到这里，X 确定不同，斜率 K := ((Q.Y - P.Y) / (Q.X - P.X)) mod p
      X := FEccInt64PolynomialPool.Obtain;
      Y := FEccInt64PolynomialPool.Obtain;
      K := FEccInt64PolynomialPool.Obtain;

      Int64PolynomialGaloisSub(Y, Q.Y, P.Y, FFiniteFieldSize);
      Int64PolynomialGaloisSub(X, Q.X, P.X, FFiniteFieldSize);

      T := FEccInt64PolynomialPool.Obtain;
      Int64PolynomialCopy(T, X);
      Int64PolynomialGaloisModularInverse(X, T, FPrimitive, FFiniteFieldSize);
      Int64PolynomialGaloisMul(K, Y, X, FFiniteFieldSize, FPrimitive); // 得到斜率
    end;

    //  X := K * K - P.X - Q.X;
    Int64PolynomialCopy(X, K);
    Int64PolynomialGaloisMul(X, X, K, FFiniteFieldSize, FPrimitive);
    Int64PolynomialGaloisSub(X, X, P.X, FFiniteFieldSize);
    Int64PolynomialGaloisSub(X, X, Q.X, FFiniteFieldSize);

    // Ysum = (K * (X1 - Xsum) - Y1) mod p
    Int64PolynomialGaloisSub(X, P.X, X, FFiniteFieldSize);
    Int64PolynomialGaloisMul(Y, K, X, FFiniteFieldSize, FPrimitive);
    Int64PolynomialGaloisSub(Y, Y, P.Y, FFiniteFieldSize);

    Int64PolynomialCopy(Sum.X, X);
    Int64PolynomialCopy(Sum.Y, Y);
  finally
    FEccInt64PolynomialPool.Recycle(K);
    FEccInt64PolynomialPool.Recycle(X);
    FEccInt64PolynomialPool.Recycle(Y);
    FEccInt64PolynomialPool.Recycle(T);
  end;
end;

//class procedure TCnInt64PolynomialEcc.PointAddPoint1(PX, PY, QX, QY, SX,
//  SY: TCnInt64Polynomial; A, B, APrime: Int64; APrimitive: TCnInt64Polynomial);
//var
//  R, E, T1, T2, T3: TCnInt64Polynomial;
//begin
//  // 该方法为 Schoof 算法中使用，传入的点坐标均具有（a(x), b(x) * y) 的形式
//  // (PX(x), PY(x) * y) + (QX(x), QY(x) * y) = (SX(x), SY(x) * y)
//
//  // 先求斜率表达式，X 不同时斜率为 y * (PY-QY)/(PX-QX) ，相同时斜率为 y * (3*PX^2 + A)/(2*PY * (x^3+Ax+B))
//  // 用 R 代表斜率中 y 的系数，那么 SX = R^2 * (x^3+Ax+B) - PX - QX       SY = R * (PX - SX) - PY
//
//  R := nil;
//  E := nil;
//  T1 := nil;
//  T2 := nil;
//  T3 := nil;
//
//  try
//    R := FEccInt64PolynomialPool.Obtain;
//    E := FEccInt64PolynomialPool.Obtain;
//    T1 := FEccInt64PolynomialPool.Obtain;
//    T2 := FEccInt64PolynomialPool.Obtain;
//    T3 := FEccInt64PolynomialPool.Obtain;
//
//    E.SetCoefficents([B, A, 0, 1]);
//    if Int64PolynomialEqual(PX, QX) then
//    begin
//      if not Int64PolynomialEqual(PY, QY) then // 竖直
//      begin
//        SX.SetZero;
//        SY.SetZero;
//        Exit;
//      end;
//
//      // 求切线斜率，计算 (3*PX^2 + A)/(2*PY * (x^3+Ax+B))
//      Int64PolynomialGaloisMul(T1, PX, PX, APrime, APrimitive);
//      Int64PolynomialGaloisMulWord(T1, 3, APrime);
//      Int64PolynomialGaloisAddWord(T1, A, APrime); // T1 得到 3*PX^2 + A
//
//      Int64PolynomialCopy(T2, PY);
//      Int64PolynomialGaloisMulWord(T2, 2, APrime);
//      Int64PolynomialGaloisMul(T2, T2, E, APrime, APrimitive); // T2 得到 2*PY * (x^3+Ax+B)
//
//      Int64PolynomialGaloisModularInverse(T3, T2, APrimitive, APrime); // T3 得到 T2^-1
//      Int64PolynomialGaloisMul(R, T1, T3, APrime, APrimitive);         // R 得到切线斜率
//    end
//    else
//    begin
//      // 求连线斜率，计算 (PY-QY)/(PX-QX)
//      Int64PolynomialGaloisSub(T1, PY, QY, APrime, APrimitive);
//      Int64PolynomialGaloisSub(T2, PX, QX, APrime, APrimitive);
//      Int64PolynomialGaloisModularInverse(T3, T2, APrimitive, APrime); // T3 得到 T2^-1
//      Int64PolynomialGaloisMul(R, T1, T3, APrime, APrimitive);         // R 得到连线斜率
//    end;
//
//    // 斜率求好后求和点，SX = R^2 * (x^3+Ax+B) - PX - QX
//    Int64PolynomialCopy(T1, R);
//    Int64PolynomialGaloisMul(T1, T1, T1, APrime, APrimitive);
//    Int64PolynomialGaloisMul(T1, T1, E, APrime, APrimitive); // T1 得到 R^2 * (x^3+Ax+B)
//
//    Int64PolynomialGaloisSub(SX, T1, PX, APrime);
//    Int64PolynomialGaloisSub(SX, SX, QX, APrime);            // 算出 SX
//
//    // 计算 SY = R * (PX - SX) - PY
//    Int64PolynomialGaloisSub(T1, PX, SX, APrime);
//    Int64PolynomialGaloisMul(T2, R, T1, APrime, APrimitive);
//    Int64PolynomialGaloisSub(SY, T2, PY, APrime);            // 算出 SY
//  finally
//    FEccInt64PolynomialPool.Recycle(T3);
//    FEccInt64PolynomialPool.Recycle(T2);
//    FEccInt64PolynomialPool.Recycle(T1);
//    FEccInt64PolynomialPool.Recycle(E);
//    FEccInt64PolynomialPool.Recycle(R);
//  end;
//end;
//
//class procedure TCnInt64PolynomialEcc.PointAddPoint2(PX, PY, QX, QY,
//  SX, SY: TCnInt64Polynomial; A, B, APrime: Int64;
//  APrimitive: TCnInt64Polynomial);
//var
//  K, X, Y, T: TCnInt64Polynomial;
//begin
//  K := nil;
//  X := nil;
//  Y := nil;
//  T := nil;
//
//  try
//    if PX.IsZero and PY.IsZero then
//    begin
//      Int64PolynomialCopy(SX, QX);
//      Int64PolynomialCopy(SY, QY);
//      Exit;
//    end
//    else if QX.IsZero and QY.IsZero then
//    begin
//      Int64PolynomialCopy(SX, PX);
//      Int64PolynomialCopy(SY, PY);
//      Exit;
//    end
//    else if Int64PolynomialEqual(PX, QX) and Int64PolynomialEqual(PY, QY) then
//    begin
//      // 俩加数是同一个点，切线斜率为两边求导，3 * X^2 + A / (2 * Y) 但如 Y = 0 则直接是无限远 0。
//      X := FEccInt64PolynomialPool.Obtain;
//      Y := FEccInt64PolynomialPool.Obtain;
//
//      // X := 3 * PX * PX + A
//      Int64PolynomialGaloisMul(X, PX, PX, APrime, APrimitive);
//      Int64PolynomialGaloisMulWord(X, 3, APrime);
//      Int64PolynomialGaloisAddWord(X, A, APrime);
//
//      // Y := 2 * PY;
//      Int64PolynomialCopy(Y, PY);
//      Int64PolynomialGaloisMulWord(Y, 2, APrime);
//
//      if Y.IsZero then
//      begin
//        SX.SetZero;
//        SY.SetZero;
//      end;
//
//      // Y := Y^-1
//      T := FEccInt64PolynomialPool.Obtain;
//      Int64PolynomialCopy(T, Y);
//      Int64PolynomialGaloisModularInverse(Y, T, APrimitive, APrime);
//
//      // K := X * Y mod APrime;
//      K := FEccInt64PolynomialPool.Obtain;
//      Int64PolynomialGaloisMul(K, X, Y, APrime, APrimitive);
//      // 得到切线斜率 K
//    end
//    else // 是不同点
//    begin
//      if Int64PolynomialEqual(PX, QX) then // 如果 X 相等，要判断 Y 是不是互反，是则和为 0，不是则挂了
//      begin
//        T := FEccInt64PolynomialPool.Obtain;
//        Int64PolynomialGaloisAdd(T, PY, QY, APrime);
//        if T.IsZero then
//        begin
//          SX.SetZero;
//          SY.SetZero;
//        end
//        else
//          raise ECnEccException.CreateFmt('Can NOT Calucate %s,%s + %s,%s',
//            [PX.ToString, PY.ToString, QX.ToString, QY.ToString]);
//
//        Exit;
//      end;
//
//      // 到这里，X 确定不同，斜率 K := ((QY - PY) / (QX - PX)) mod p
//      X := FEccInt64PolynomialPool.Obtain;
//      Y := FEccInt64PolynomialPool.Obtain;
//      K := FEccInt64PolynomialPool.Obtain;
//
//      Int64PolynomialGaloisSub(Y, QY, PY, APrime);
//      Int64PolynomialGaloisSub(X, QX, PX, APrime);
//
//      T := FEccInt64PolynomialPool.Obtain;
//      Int64PolynomialCopy(T, X);
//      Int64PolynomialGaloisModularInverse(X, T, APrimitive, APrime);
//      Int64PolynomialGaloisMul(K, Y, X, APrime, APrimitive); // 得到斜率
//    end;
//
//    //  X := K * K - PX - QX;
//    Int64PolynomialCopy(X, K);
//    Int64PolynomialGaloisMul(X, X, K, APrime, APrimitive);
//    Int64PolynomialGaloisSub(X, X, PX, APrime);
//    Int64PolynomialGaloisSub(X, X, QX, APrime);
//
//    // SY = (K * (X1 - SX) - Y1) mod p
//    Int64PolynomialGaloisSub(X, PX, X, APrime);
//    Int64PolynomialGaloisMul(Y, K, X, APrime, APrimitive);
//    Int64PolynomialGaloisSub(Y, Y, PY, APrime);
//
//    Int64PolynomialCopy(SX, X);
//    Int64PolynomialCopy(SY, Y);
//  finally
//    FEccInt64PolynomialPool.Recycle(K);
//    FEccInt64PolynomialPool.Recycle(X);
//    FEccInt64PolynomialPool.Recycle(Y);
//    FEccInt64PolynomialPool.Recycle(T);
//  end;
//end;

procedure TCnInt64PolynomialEcc.PointInverse(
  P: TCnInt64PolynomialEccPoint);
var
  I: Integer;
begin
  for I := 0 to P.Y.MaxDegree do
    P.Y[I] := FFiniteFieldSize - P.Y[I];
end;

procedure TCnInt64PolynomialEcc.PointSubPoint(P, Q,
  Diff: TCnInt64PolynomialEccPoint);
var
  Inv: TCnInt64PolynomialEccPoint;
begin
  Inv := TCnInt64PolynomialEccPoint.Create;
  try
    Inv.Assign(Q);
    PointInverse(Inv);
    PointAddPoint(P, Inv, Diff);
  finally
    Inv.Free;
  end;
end;

class procedure TCnInt64PolynomialEcc.RationalMultiplePoint(K: Integer;
  MX, MY: TCnInt64RationalPolynomial; A, B, APrime: Int64; APrimitive: TCnInt64Polynomial);
var
  Neg: Boolean;
  FN, FNa1, FNa2, FNs1, FNs2, P1, P2, X1, Y2: TCnInt64Polynomial;
begin
  if K = 0 then
  begin
    MX.SetZero;
    MY.SetZero;
    Exit;
  end;

  Neg := K < 0;
  if Neg then
    K := -K;

  if K = 1 then // 没乘，原封不动返回 x 和 1
  begin
    MX.Nominator.SetCoefficents([0, 1]);
    MX.Denominator.SetOne;

    MY.Nominator.SetOne;
    MY.Denominator.SetOne;
  end
  else
  begin
    FN := FEccInt64PolynomialPool.Obtain;
    FNa1 := FEccInt64PolynomialPool.Obtain;
    FNa2 := FEccInt64PolynomialPool.Obtain;
    FNs1 := FEccInt64PolynomialPool.Obtain;
    FNs2 := FEccInt64PolynomialPool.Obtain;
    X1 := FEccInt64PolynomialPool.Obtain;
    Y2 := FEccInt64PolynomialPool.Obtain;
    P1 := FEccInt64PolynomialPool.Obtain;
    P2 := FEccInt64PolynomialPool.Obtain;

    try
      X1.SetCoefficents([0, 1]);
      Y2.SetCoefficents([B, A, 0, 1]);

      Int64PolynomialGaloisCalcDivisionPolynomial(A, B, K, FN, APrime);
      Int64PolynomialGaloisCalcDivisionPolynomial(A, B, K + 1, FNa1, APrime);
      Int64PolynomialGaloisCalcDivisionPolynomial(A, B, K + 2, FNa2, APrime);
      Int64PolynomialGaloisCalcDivisionPolynomial(A, B, K - 1, FNs1, APrime);
      Int64PolynomialGaloisCalcDivisionPolynomial(A, B, K - 2, FNs2, APrime);

      // 求 X 表达式
      if (K and 1) = 0 then // K 偶数时
      begin
        // 结果的 x 坐标为 (x*fn^2 * Y^2 - fn+1 * fn-1) / fn^2 * Y^2
        Int64PolynomialGaloisMul(MX.Denominator, FN, FN, APrime);
        Int64PolynomialGaloisMul(MX.Denominator, MX.Denominator, Y2, APrime);

        Int64PolynomialGaloisMul(P1, FNa1, FNs1, APrime); // P1 得到 fn+1 * fn-1
        Int64PolynomialGaloisMul(P2, FN, FN, APrime);
        Int64PolynomialGaloisMul(P2, P2, X1, APrime);     // P2 得到 x*fn^2
        Int64PolynomialGaloisMul(P2, P2, Y2, APrime);     // P2 得到 x*fn^2 * Y^2

        Int64PolynomialGaloisSub(MX.Nominator, P2, P1, APrime); // MX 计算完毕
      end
      else // K 奇数时
      begin
        // 结果的 x 坐标为 (x*fn^2 - Y^2 * fn+1 * fn-1) / fn^2
        Int64PolynomialGaloisMul(MX.Denominator, FN, FN, APrime);

        Int64PolynomialGaloisMul(P1, FNa1, FNs1, APrime); // P1 得到 fn+1 * fn-1
        Int64PolynomialGaloisMul(P1, P1, Y2, APrime);     // P1 得到 Y^2 * fn+1 * fn-1

        Int64PolynomialGaloisMul(P2, FN, FN, APrime);
        Int64PolynomialGaloisMul(P2, P2, X1, APrime);     // P2 得到 x*fn^2
        Int64PolynomialGaloisSub(MX.Nominator, P2, P1, APrime); // MX 计算完毕
      end;

      // 求 Y 表达式
      if K = 2 then // Y 的分子是 f2n，n 为 2 时不需递归，直接用 f4
      begin
        Int64PolynomialCopy(MY.Nominator, FNa2);
      end
      else
      begin
        // 结果的 y 坐标分子为 fn+2 * fn-1^2 - fn-2 * fn+1 ^2
        Int64PolynomialGaloisMul(P1, FNs1, FNs1, APrime);
        Int64PolynomialGaloisMul(P1, P1, FNa2, APrime);
        Int64PolynomialGaloisMul(P2, FNa1, FNa1, APrime);
        Int64PolynomialGaloisMul(P2, P2, FNs2, APrime);

        Int64PolynomialGaloisSub(MY.Nominator, P1, P2, APrime); // MY 分子计算完毕
      end;

      Int64PolynomialGaloisPower(MY.Denominator, FN, 3, APrime);
      Int64PolynomialGaloisMulWord(MY.Denominator, 4, APrime);   // 奇数分母 4 * fn^3 计算完毕

      if (K and 1) = 0 then // 偶数分母还得乘以 y^4
      begin
        Int64PolynomialGaloisMul(MY.Denominator, Y2, MY.Denominator, APrime);
        Int64PolynomialGaloisMul(MY.Denominator, Y2, MY.Denominator, APrime);
      end;
    finally
      FEccInt64PolynomialPool.Recycle(FN);
      FEccInt64PolynomialPool.Recycle(FNa1);
      FEccInt64PolynomialPool.Recycle(FNa2);
      FEccInt64PolynomialPool.Recycle(FNs1);
      FEccInt64PolynomialPool.Recycle(FNs2);
      FEccInt64PolynomialPool.Recycle(X1);
      FEccInt64PolynomialPool.Recycle(Y2);
      FEccInt64PolynomialPool.Recycle(P1);
      FEccInt64PolynomialPool.Recycle(P2);
    end;
  end;

  if Neg then
    MY.Neg;

  if APrimitive <> nil then
  begin
    Int64PolynomialGaloisMod(MX.Nominator, MX.Nominator, APrimitive, APrime);
    Int64PolynomialGaloisMod(MX.Denominator, MX.Denominator, APrimitive, APrime);
    Int64PolynomialGaloisMod(MY.Nominator, MY.Nominator, APrimitive, APrime);
    Int64PolynomialGaloisMod(MY.Denominator, MY.Denominator, APrimitive, APrime);
  end;
end;

class procedure TCnInt64PolynomialEcc.RationalPointAddPoint(PX, PY, QX, QY,
  SX, SY: TCnInt64RationalPolynomial; A, B, APrime: Int64; APrimitive: TCnInt64Polynomial);
var
  R, T1, T2: TCnInt64RationalPolynomial;
  Y2, C: TCnInt64Polynomial;
begin
  // 点 (PX, PY * y) + (QX, QY * y) = (SX, SY * y)
  // 先求斜率 R = y * (QY - PY) / (QX - PX) 或 (3PX^2 + A) / 2PY * y

  R := nil;
  T1 := nil;
  T2 := nil;

  Y2 := nil;
  C := nil;

  try
    R := TCnInt64RationalPolynomial.Create;
    T1 := TCnInt64RationalPolynomial.Create;
    T2 := TCnInt64RationalPolynomial.Create;

    Y2 := FEccInt64PolynomialPool.Obtain;
    C := FEccInt64PolynomialPool.Obtain;
    Y2.SetCoefficents([B, A, 0, 1]);

    if Int64RationalPolynomialGaloisEqual(PX, QX, APrime, APrimitive) then // 不能直接判断相等，得互乘后各自针对本原多项式求余后再判断相等
    begin
      // X 相等，判断 Y 是否相等，不等则假设它们相反，返回 0
      // TODO: 判断 PY QY 是否相反
      if not Int64RationalPolynomialGaloisEqual(PY, QY, APrime, APrimitive) then
      begin
        SX.SetZero;
        SY.SetZero;
        Exit;
      end;

      // X Y 都相等，求导
      C.SetCoefficents([3]);

      Int64RationalPolynomialGaloisMul(PX, PX, T1, APrime);
      Int64RationalPolynomialGaloisMul(T1, C, T1, APrime);  // T1 得到 3PX^2

      C.SetCoefficents([A]);
      Int64RationalPolynomialGaloisAdd(T1, C, T1, APrime);  // T1 得到 3PX^2 + A

      C.SetCoefficents([2]);
      Int64RationalPolynomialGaloisMul(PY, C, T2, APrime);  // T2 得到 2PY，实际上还要乘以一个 y

      Int64RationalPolynomialGaloisDiv(T1, T2, R, APrime);  // 得到斜率 R，但真实的斜率分母实际上还要乘以一个 y，后面补上

      // SX = 真实斜率^2 - PX - QX = R^2 / (x^3+Ax+B) - PX - QX
      // 真实斜率的平方 = R^2 / y^2，分母可替换成 x^3+Ax+B
      Int64RationalPolynomialGaloisMul(R, R, SX, APrime);
      Int64RationalPolynomialGaloisDiv(SX, Y2, SX, APrime);
      Int64RationalPolynomialGaloisSub(SX, PX, SX, APrime);
      Int64RationalPolynomialGaloisSub(SX, QX, SX, APrime);

      if APrimitive <> nil then
      begin
        Int64PolynomialGaloisMod(SX.Nominator, SX.Nominator, APrimitive, APrime);
        Int64PolynomialGaloisMod(SX.Denominator, SX.Denominator, APrimitive, APrime);
      end;

      // SY * y = 真实斜率 * (PX - SX) - PY * y
      // SY = (R/y * (PX - SX) - PY * y) / y = R * (PX - SX)/ y^2 - PY
      Int64RationalPolynomialGaloisSub(PX, SX, SY, APrime);
      Int64RationalPolynomialGaloisMul(SY, R, SY, APrime);
      Int64RationalPolynomialGaloisDiv(SY, Y2, SY, APrime);
      Int64RationalPolynomialGaloisSub(SY, PY, SY, APrime);

      if APrimitive <> nil then
      begin
        Int64PolynomialGaloisMod(SY.Nominator, SY.Nominator, APrimitive, APrime);
        Int64PolynomialGaloisMod(SY.Denominator, SY.Denominator, APrimitive, APrime);
      end;
    end
    else
    begin
      // 不相等，减，真实斜率等于 y * (QY - PY) / (QX - PX)
      Int64RationalPolynomialGaloisSub(QY, PY, T1, APrime);
      Int64RationalPolynomialGaloisSub(QX, PX, T2, APrime);
      Int64RationalPolynomialGaloisDiv(T1, T2, R, APrime);

      // R 得到斜率了，但真实的斜率分子实际上还要乘以一个 y，后面补上
      // SX = R^2 * (x^3+Ax+B) - PX - QX
      Int64RationalPolynomialGaloisMul(R, R, SX, APrime);
      Int64RationalPolynomialGaloisMul(SX, Y2, SX, APrime);
      Int64RationalPolynomialGaloisSub(SX, PX, SX, APrime);
      Int64RationalPolynomialGaloisSub(SX, QX, SX, APrime);

      if APrimitive <> nil then
      begin
        Int64PolynomialGaloisMod(SX.Nominator, SX.Nominator, APrimitive, APrime);
        Int64PolynomialGaloisMod(SX.Denominator, SX.Denominator, APrimitive, APrime);
      end;

      // SY * y = R * y * (PX - SX) - PY * y 都除以 y 得 SY = R * (PX - SX) - PY
      Int64RationalPolynomialGaloisSub(PX, SX, SY, APrime);
      Int64RationalPolynomialGaloisMul(SY, R, SY, APrime);
      Int64RationalPolynomialGaloisSub(SY, PY, SY, APrime);

      if APrimitive <> nil then
      begin
        Int64PolynomialGaloisMod(SY.Nominator, SY.Nominator, APrimitive, APrime);
        Int64PolynomialGaloisMod(SY.Denominator, SY.Denominator, APrimitive, APrime);
      end;
    end;
  finally
    FEccInt64PolynomialPool.Recycle(Y2);
    FEccInt64PolynomialPool.Recycle(C);

    T2.Free;
    T1.Free;
    R.Free;
  end;
end;

procedure TCnInt64PolynomialEcc.SetPrimitive(
  const Value: TCnInt64Polynomial);
begin
  if Value <> nil then
  begin
    if Value.MaxDegree <> FExtension then
      raise ECnEccException.Create('Primitive Polynomial Max Degree must be Field Extension.');
    Int64PolynomialCopy(FPrimitive, Value);
  end;
end;

procedure CnInt64GenerateGaloisDivisionPolynomials(A, B, Prime: Int64; MaxDegree: Integer;
  PolynomialList: TObjectList);
var
  I, N: Integer;

  // 返回第 Degree 个可除表达式的引用，并同时存入 PolynomialList 的对应位置，注意返回值不要改动
  function GetInt64GaloisDivisionPolynomial(Degree: Integer): TCnInt64Polynomial;
  var
    MI, T1, T2: Int64;
    F1, F2, F3, F4, F5: TCnInt64Polynomial;  // 从递归 GetInt64GaloisDivisionPolynomial 拿到的引用，不允许改动
    D1, D2, D3, Y4: TCnInt64Polynomial;      // 计算中间结果，要创建要释放
  begin
    if PolynomialList[Degree] <> nil then // 如果有缓存就返回缓存的
    begin
      Result := TCnInt64Polynomial(PolynomialList[Degree]);
      Exit;
    end;

    if Degree = 0 then
    begin
      Result := TCnInt64Polynomial.Create;
      Result.SetCoefficents([0]);  // f0(X) = 0
      PolynomialList[0] := Result;
    end
    else if Degree = 1 then
    begin
      Result := TCnInt64Polynomial.Create;
      Result.SetCoefficents([1]);  // f1(X) = 1
      PolynomialList[1] := Result;
    end
    else if Degree = 2 then
    begin
      Result := TCnInt64Polynomial.Create;
      Result.SetCoefficents([2]);  // f2(X) = 2
      PolynomialList[2] := Result;
    end
    else if Degree = 3 then   // f3(X) = 3 X4 + 6 a X2 + 12 b X - a^2
    begin
      Result := TCnInt64Polynomial.Create;
      Result.MaxDegree := 4;
      Result[4] := 3;
      Result[3] := 0;
      Result[2] := Int64NonNegativeMulMod(6, A, Prime);
      Result[1] := Int64NonNegativeMulMod(12, B, Prime);
      Result[0] := Int64NonNegativeMulMod(-A, A, Prime);

      PolynomialList[3] := Result;
    end
    else if Degree = 4 then // f4(X) = 4 X6 + 20 a X4 + 80 b X3 - 20 a2X2 - 16 a b X - 4 a3 - 32 b^2
    begin
      Result := TCnInt64Polynomial.Create;
      Result.MaxDegree := 6;
      Result[6] := 4;
      Result[5] := 0;
      Result[4] := Int64NonNegativeMulMod(20, A, Prime);
      Result[3] := Int64NonNegativeMulMod(80, B, Prime);
      Result[2] := Int64NonNegativeMulMod(Int64NonNegativeMulMod(-20, A, Prime), A, Prime);
      Result[1] := Int64NonNegativeMulMod(Int64NonNegativeMulMod(-16, A, Prime), B, Prime);
      T1 := Int64NonNegativeMulMod(Int64NonNegativeMulMod(Int64NonNegativeMulMod(-4, A, Prime), A, Prime), A, Prime);
      T2 := Int64NonNegativeMulMod(Int64NonNegativeMulMod(-32, B, Prime), B, Prime);
      Result[0] := Int64NonNegativeMod(T1 + T2, Prime); // TODO: 暂未处理相加溢出的取模

      PolynomialList[4] := Result;
    end
    else
    begin
      // 计算第 Degree 个可除表达式，中间可能递归调用到自身，同样尽量从缓存中取
      D1 := nil;
      D2 := nil;
      D3 := nil;
      Y4 := nil;

      try
        // 开始递归计算
        N := Degree shr 1;
        if (Degree and 1) = 0 then // Degree 是偶数
        begin
          F1 := GetInt64GaloisDivisionPolynomial(N + 2); // F1 得到 Fn+2
          F2 := GetInt64GaloisDivisionPolynomial(N - 1); // F2 得到 Fn-1

          D2 := FEccInt64PolynomialPool.Obtain;
          Int64PolynomialGaloisMul(D2, F2, F2, Prime);   // D2 得到 Fn-1 ^ 2

          D1 := FEccInt64PolynomialPool.Obtain;
          Int64PolynomialGaloisMul(D1, F1, D2, Prime);   // D1 得到 Fn+2 * Fn-1 ^ 2

          F3 := GetInt64GaloisDivisionPolynomial(N - 2);  // F3 得到 Fn-2
          F4 := GetInt64GaloisDivisionPolynomial(N + 1);  // F4 得到 Fn+1

          Int64PolynomialGaloisMul(D2, F4, F4, Prime);   // D2 得到 Fn+1 ^ 2
          Int64PolynomialGaloisMul(D2, D2, F3, Prime);   // D2 得到 Fn-2 * Fn+1 ^ 2

          Int64PolynomialGaloisSub(D1, D1, D2, Prime);   // D1 得到 Fn+2 * Fn-1 ^ 2 - Fn-2 * Fn+1 ^ 2

          F5 := GetInt64GaloisDivisionPolynomial(N);     // F5 得到 Fn

          Result := TCnInt64Polynomial.Create;
          Int64PolynomialGaloisMul(Result, F5, D1, Prime);           // 相乘得到 Fn * (Fn+2 * Fn-1 ^ 2 - Fn-2 * Fn+1 ^ 2)

          MI := CnInt64ModularInverse(2, Prime);
          Int64PolynomialGaloisMulWord(Result, MI, Prime);           // 再除以 2

          PolynomialList[Degree] := Result;
        end
        else // Degree 是奇数
        begin
          Y4 := FEccInt64PolynomialPool.Obtain;
          Y4.SetCoefficents([B, A, 0, 1]);
          Int64PolynomialGaloisMul(Y4, Y4, Y4, Prime);

          F1 := GetInt64GaloisDivisionPolynomial(N + 2); // F1 得到 Fn+2

          D2 := FEccInt64PolynomialPool.Obtain;
          F2 := GetInt64GaloisDivisionPolynomial(N);     // F2 得到 Fn
          Int64PolynomialGaloisPower(D2, F2, 3, Prime);  // D2 得到 Fn^3

          D3 := FEccInt64PolynomialPool.Obtain;
          F3 := GetInt64GaloisDivisionPolynomial(N + 1); // F3 得到 Fn+1
          Int64PolynomialGaloisPower(D3, F3, 3, Prime);  // D3 得到 Fn+1 ^ 3

          if (N and 1) <> 0 then // N 是奇数
          begin
            D1 := FEccInt64PolynomialPool.Obtain;
            Int64PolynomialGaloisMul(D1, F1, D2, Prime);     // D1 得到 Fn+2 * Fn ^ 3，并释放 D2

            F4 := GetInt64GaloisDivisionPolynomial(N - 1);
            Int64PolynomialGaloisMul(D2, F4, Y4, Prime);     // D2 得到 Fn-1 * Y^2

            Int64PolynomialGaloisMul(D2, D2, D3, Prime);     // D2 得到 Fn+1 ^ 3 * Fn-1(Y)

            Result := TCnInt64Polynomial.Create;
            Int64PolynomialGaloisSub(Result, D1, D2, Prime); // D1 - D2

            PolynomialList[Degree] := Result;
          end
          else // N 是偶数
          begin
            D1 := FEccInt64PolynomialPool.Obtain;
            Int64PolynomialGaloisMul(D1, F1, D2, Prime);     // D1 得到 Fn+2 * Fn ^ 3，并释放 D2
            Int64PolynomialGaloisMul(D1, D1, Y4, Prime);     // D1 得到 Y * Fn+2 * Fn ^ 3

            F4 := GetInt64GaloisDivisionPolynomial(N - 1);   // F4 得到 Fn-1

            Int64PolynomialGaloisMul(D2, F4, D3, Prime);     // D2 得到 Fn+1 ^ 3 * Fn-1

            Result := TCnInt64Polynomial.Create;
            Int64PolynomialGaloisSub(Result, D1, D2, Prime); // D1 - D2

            PolynomialList[Degree] := Result;
          end;
        end;
      finally
        FEccInt64PolynomialPool.Recycle(D1);
        FEccInt64PolynomialPool.Recycle(D2);
        FEccInt64PolynomialPool.Recycle(D3);
        FEccInt64PolynomialPool.Recycle(Y4);
      end;
    end;
  end;

begin
  // 生成 0 至 MaxDegree 的可除多项式并存储于 PolynomialList 中。
  PolynomialList.Clear;
  PolynomialList.Count := MaxDegree + 1;

  for I := 0 to MaxDegree do
    GetInt64GaloisDivisionPolynomial(I);
end;

function CnInt64EccSchoof(A, B, Q: Int64): Int64;
var
  Pa, Ta: TCnInt64List;
  QMul, QMax, L, K, W: Int64;
  I, J: Integer;
  Q2Lo, Q2Hi: TUInt64;
  F, G, Y2, P1, P2, LDP: TCnInt64Polynomial;
  Pi2PX, Pi2PY, PiPX, PiPY, KPX, KPY, LSX, LSY, RSX, RSY, TSX, TSY: TCnInt64RationalPolynomial;
  F1, F2, F3, F4, F5: TCnInt64Polynomial; // 可除多项式引用，不可改变
  DPs: TObjectList;
begin
  // 用 Schoof 算法求椭圆曲线 y^2 = x^3 + Ax + B 在素域 Fq 上的点总数
  // 先建个 List，存所需的 2 ~ lmax 的素数，其中 3 * ... * lmax 刚好 > 4 倍根号 q
  // 求 x^q -x 与 x^3 + Ax + B 的公因式，如果是 1 则 t2 = 1，否则 t2 = 0，
  // 这里 t2 是 List 中针对素数 2 的元素，并非下标，后面同

  Pa := TCnInt64List.Create;
  Ta := TCnInt64List.Create;

  Y2 := FEccInt64PolynomialPool.Obtain;
  P1 := FEccInt64PolynomialPool.Obtain;
  P2 := FEccInt64PolynomialPool.Obtain;

  F := FEccInt64PolynomialPool.Obtain;
  G := FEccInt64PolynomialPool.Obtain;

  QMax := 1 + 4 * UInt64Sqrt(Q);
  QMul := 1;
  I := Low(CN_PRIME_NUMBERS_SQRT_UINT32);

  DPs := nil;
  Pi2PX := TCnInt64RationalPolynomial.Create;
  Pi2PY := TCnInt64RationalPolynomial.Create;
  PiPX := TCnInt64RationalPolynomial.Create;
  PiPY := TCnInt64RationalPolynomial.Create;
  KPX := TCnInt64RationalPolynomial.Create;
  KPY := TCnInt64RationalPolynomial.Create;
  LSX := TCnInt64RationalPolynomial.Create;
  LSY := TCnInt64RationalPolynomial.Create;
  RSX := TCnInt64RationalPolynomial.Create;
  RSY := TCnInt64RationalPolynomial.Create;
  TSX := TCnInt64RationalPolynomial.Create;
  TSY := TCnInt64RationalPolynomial.Create;

  try
    Pa := TCnInt64List.Create;
    Ta := TCnInt64List.Create;

    while (QMul <= QMax) and (I <= High(CN_PRIME_NUMBERS_SQRT_UINT32)) do
    begin
      QMul := QMul * CN_PRIME_NUMBERS_SQRT_UINT32[I];
      Pa.Add(CN_PRIME_NUMBERS_SQRT_UINT32[I]);
      Ta.Add(0);
      Inc(I);
    end;

    if I > High(CN_PRIME_NUMBERS_SQRT_UINT32) then
      raise ECnEccException.Create('Prime Number is Too Large.');

    Y2.SetCoefficents([B, A, 0, 1]);

    // Ta 与 Pa 数组已准备好，先处理 t = 2 的情况
    P1.SetCoefficents([0, 1]); // P1 := X
    Int64PolynomialGaloisPower(P1, P1, Q, Q, Y2); // X^q 先 mod Y^2

    P2.SetCoefficents([0, 1]); // P2 := X
    Int64PolynomialGaloisSub(P1, P1, P2, Q); // P1 := (X^q mod Y^2) - x

    // 求最大公约式
    Int64PolynomialGaloisGreatestCommonDivisor(G, P1, Y2, Q);

    if G.IsOne then
      Ta[0] := 1
    else
      Ta[0] := 0;   // 求得 T2。理解了并且基本算对了

    // 提前算好最大素数 + 2 阶的可除多项式们以及准备好 Y^2
    DPs := TObjectList.Create(True);
    CnInt64GenerateGaloisDivisionPolynomials(A, B, Q, Pa[Pa.Count - 1] + 2, DPs);

    for I := 1 to Ta.Count - 1 do  // 针对每一个 L
    begin
      L := Pa[I];
      K := Q mod L;

      // 先得到 L 阶可除多项式，作为后续计算的模多项式
      LDP := TCnInt64Polynomial(DPs[L]);

      Pi2PX.SetOne;                           // 原始点
      Pi2PX.Nominator.SetCoefficents([0, 1]); // x
      Pi2PY.Setone;                           // 1 * y

      // 算得 π^2 的 X 坐标在 LDP 环内的表达分式，也就是 Q*Q 个 x 相乘再 mod LDP
      Int64PolynomialGaloisPower(Pi2PX.Nominator, Pi2PX.Nominator, Q, Q, LDP);
      Int64PolynomialGaloisPower(Pi2PX.Nominator, Pi2PX.Nominator, Q, Q, LDP);  // 直接 Q*Q 容易溢出，分步算

      // 算得 π^2 的 Y 坐标在 LDP 环内的表达分式，Q*Q 个 y 相乘等于 y * [(Q*Q shr 1) 个 y^2 相乘]，而 y^2 可替换成 x^3+Ax+B
      UInt64MulUInt64(Q, Q, Q2Lo, Q2Hi);
      if Q2Hi = 0 then
        Int64PolynomialGaloisPower(Pi2PY.Nominator, Y2, (Q * Q) shr 1, Q, LDP)
      else if Q2Hi = 1 then
      begin
        // 处理 (Q * Q) > UInt64 但 (Q * Q) shr 1 < UInt64 的情形
        Q2Lo := Q2Lo shr 1;
        Q2Lo := Q2Lo or $F000000000000000;
        Int64PolynomialGaloisPower(Pi2PY.Nominator, Y2, Q2Lo, Q, LDP);
      end
      else
        raise ECnEccException.Create('Prime Number is Too Large!');
      // TODO: 再大就容易溢出了，暂无好办法

      KPX.SetOne;                             // 原始点
      KPX.Nominator.SetCoefficents([0, 1]);   // x
      KPY.SetOne;                             // 1 * y

      // 算得 K * P 的 X Y 坐标
      TCnInt64PolynomialEcc.RationalMultiplePoint(K, KPX, KPY, A, B, Q, LDP);

      PiPX.SetOne;                            // 原始点
      PiPX.Nominator.SetCoefficents([0, 1]);  // x
      PiPY.Setone;                            // 1 * y

      // 求 π^2(P) + K * (P) 的和点 SX SY
      TCnInt64PolynomialEcc.RationalPointAddPoint(Pi2PX, Pi2PY, KPX, KPY, LSX, LSY, A, B, Q, LDP);
      if LSX.IsZero and LSY.IsZero then  // 如果和点为 0，则表示 t * π结果等于 0，t 自然等于 0
        Ta[I] := 0
      else
      begin
        // 算得 π的 X 坐标在 LDP 环内的表达分式，也就是 Q 个 x 相乘再 mod LDP
        Int64PolynomialGaloisPower(PiPX.Nominator, PiPX.Nominator, Q, Q, LDP);

        // 算得 π的 Y 坐标在 LDP 环内的表达分式，Q 个 y 相乘等于 y * [(Q shr 1) 个 y^2 相乘]，而 y^2 可替换成 x^3+Ax+B
        Int64PolynomialGaloisPower(PiPY.Nominator, Y2, Q shr 1, Q, LDP);

        Int64RationalPolynomialCopy(RSX, PiPX);
        Int64RationalPolynomialCopy(RSY, PiPY);
        for J := 1 to (L + 1) shr 1 do
        begin
          if Int64RationalPolynomialGaloisEqual(LSX, RSX, Q, LDP) then
          begin
            if Int64RationalPolynomialGaloisEqual(LSY, RSY, Q, LDP) then
              Ta[I] := J
            else
              Ta[I] := L - J;
            Break;
          end;

          TCnInt64PolynomialEcc.RationalPointAddPoint(RSX, RSY, PiPX, PiPY, TSX, TSY, A, B, Q, LDP);
          Int64RationalPolynomialCopy(RSX, TSX);
          Int64RationalPolynomialCopy(RSY, TSY);
        end;
      end;
    end;

    // 求出各个余数后，用中国剩余定理求最终解
    L := ChineseRemainderTheoremInt64(Ta, Pa); // 复用 L W K 等变量

    // 注意求出的 T 必须满足 Hasse 定理：T 的绝对值 <= 2 * 根号 Q，如超出范围，还得修正
    K := UInt64Sqrt(TUInt64(Q)) * 2 + 1;
    if (L <= -K) or (L >= K) then
    begin
      // 中国剩余定理求出的一般是最小正数，需要减去全体 Pa 的乘积
      W := 1;
      for J := 0 to Pa.Count - 1 do
        W := W * Pa[J];

      if L <= -B then
        L := L + W
      else
        L := L - W;
    end;

    Result := Q + 1 - L;
  finally
    FEccInt64PolynomialPool.Recycle(Y2);
    FEccInt64PolynomialPool.Recycle(P1);
    FEccInt64PolynomialPool.Recycle(P2);

    FEccInt64PolynomialPool.Recycle(G);
    FEccInt64PolynomialPool.Recycle(F);

    Pi2PX.Free;
    Pi2PY.Free;
    PiPX.Free;
    PiPY.Free;
    KPX.Free;
    KPY.Free;
    LSX.Free;
    LSY.Free;
    RSX.Free;
    RSY.Free;
    TSX.Free;
    TSY.Free;

    DPs.Free;
    Pa.Free;
    Ta.Free;
  end;
end;

initialization
  FEccBigNumberPool := TCnBigNumberPool.Create;
  FEccInt64PolynomialPool := TCnInt64PolynomialPool.Create;

finalization
  FEccInt64PolynomialPool.Free;
  FEccBigNumberPool.Free;

end.
