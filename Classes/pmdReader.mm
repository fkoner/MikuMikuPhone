//
//  pmdReader.mm
//  MikuMikuPhone
//
//  Created by hakuroum on 1/14/11.
//  Copyright 2011 hakuroum@gmail.com . All rights reserved.
//

#import "pmdReader.h"

#pragma mark Ctor
pmdReader::pmdReader()
{
}

#pragma mark Dtor
pmdReader::~pmdReader()
{
	for( int32_t i = 0; i < _iNumMaterials; ++i )
	{
		if( _pMaterials[ i ]._tex2D )
		{
			[_pMaterials[ i ]._tex2D release];
		}
	}

	if( _data )
	{
		[_data release];
	}
}

#pragma mark Init
bool pmdReader::init( NSString* strFileName )
{
	_data = [[NSData dataWithContentsOfFile:strFileName options:NSDataReadingUncached error:nil] retain];
	if( !_data )
    {
        NSLog(@"Failed to load data");
        return FALSE;
    }
	
    _pData = (int8_t*)[_data bytes];
    if (!_pData)
    {
        NSLog(@"Failed to load data");
        return FALSE;
    }
	_iOffset = 0;
	
	if( verifyHeader() == false )
		return false;
	
	if( !parseVertices() )
		return false;
	if( !parseIndices() )
		return false;
	if( !parseMaterials() )
		return false;
	if( !parseBones() )
		return false;
	if( !parseIKs() )
		return false;
	if( !parseSkins() )
		return false;
	
	//Just ignore other stuff...
	
	return true;	
}

#pragma mark Parser
int16_t pmdReader::getShort()
{
	int16_t i =  *(int16_t*)&_pData[ _iOffset ];
	_iOffset += sizeof( int16_t );
	return i;
}

int32_t pmdReader::getInteger()
{
	int32_t i =  *(int32_t*)&_pData[ _iOffset ];
	_iOffset += sizeof( int32_t );
	return i;
}

float pmdReader::getFloat()
{
	float f =  *(float*)&_pData[ _iOffset ];
	_iOffset += sizeof( float );
	return f;
}

bool pmdReader::parseVertices()
{
	int32_t iVertices = getInteger();
	NSLog( @"Num vertices: %d", iVertices );
	_iNumVertices = iVertices;
	_pVertices = (vertex*)&_pData[ _iOffset ];
	_iOffset += iVertices * sizeof( vertex );
	
	//Reverse Z
	for( int32_t i = 0; i < iVertices; ++i )
	{
		_pVertices[ i ].pos[ 2 ] = -_pVertices[ i ].pos[ 2 ];
	}
	
	if( _iOffset > [_data length] )
		return false;
		
	return true;
}

bool pmdReader::parseIndices()
{
	int32_t iIndices = getInteger();
	NSLog( @"Num Indices: %d", iIndices );
	_iNumIndices = iIndices;	//Num triangles /=3
	_pIndices = (uint16_t*)&_pData[ _iOffset ];
	_iOffset += iIndices * sizeof( uint16_t );
	
	if( _iOffset > [_data length] )
		return false;
	
	return true;
}

bool pmdReader::parseMaterials()
{
	int32_t i = getInteger();
	NSLog( @"Num Materials: %d", i );
	_iNumMaterials = i;
	_pMaterials = (material*)&_pData[ _iOffset ];
	_iOffset += i * sizeof( material );
	
	if( _iOffset > [_data length] )
		return false;
	
	for( int32_t i = 0; i < _iNumMaterials; ++i )
	{
		if( _pMaterials[ i ].texture_file_name[ 0 ] != 0 )
		{
			NSString* strFile = [NSString stringWithUTF8String: _pMaterials[ i ].texture_file_name];
			NSLog( @"Texture:%s", _pMaterials[ i ].texture_file_name );
			_pMaterials[ i ]._tex2D = [[Texture2D alloc] initWithImage: [UIImage imageNamed:strFile]];
			_pMaterials[ i ]._tex = _pMaterials[ i ]._tex2D.name;
			
		}
		else
		{
			_pMaterials[ i ]._tex2D = nil;
			_pMaterials[ i ]._tex = 0;
		}
	}

	return true;
}

bool pmdReader::parseBones()
{
	int32_t i = getShort();
	NSLog( @"Num Bones: %d", i );
	_iNumBones = i;
	_pBones = (bone*)&_pData[ _iOffset ];
	_iOffset += i * sizeof( bone );
	
	if( _iOffset > [_data length] )
		return false;
	
	return true;
}

bool pmdReader::parseIKs()
{
	int32_t iNumIK = getShort();
	NSLog( @"Num IKs: %d", iNumIK );
	_iNumIKs = iNumIK;
	_pIKs = (ik*)&_pData[ _iOffset ];
	
	for( int32_t i = 0; i < iNumIK; ++i )
	{
		ik* currentIK = (ik*)&_pData[ _iOffset ];
		int32_t iChains = currentIK->ik_chain_length;
		NSLog( @"Chans %d, %d", i, iChains );
		_iOffset += sizeof( ik ) + iChains * sizeof( uint16_t );
	}

	if( _iOffset > [_data length] )
		return false;
	
	return true;
}

bool pmdReader::parseSkins()
{
	int32_t iNumSkins = getShort();
	NSLog( @"Num Skins: %d", iNumSkins );
	_iNumSkins = iNumSkins;
	_pSkins = (skin*)&_pData[ _iOffset ];
	
	for( int32_t i = 0; i < iNumSkins; ++i )
	{
		skin* currentSkin = (skin*)&_pData[ _iOffset ];
		int32_t iVertices = currentSkin->skin_vert_count;
		NSLog( @"Skin %d, %d", i, iVertices );
		_iOffset += sizeof( skin ) + iVertices * sizeof( skin_vertex );
	}
	
	if( _iOffset > [_data length] )
		return false;
	
	return true;
}

bool pmdReader::verifyHeader()
{
	const int32_t PMD_MAGIC = 'd' << 16 | 'm' << 8 | 'P';
	const float PMD_VERSION = 1.f;
	const int32_t PMD_MODELNAME_SIZE = 20;
	const int32_t PMD_COMMENT_SIZE = 256;
	
	if( !_pData )
		return false;

	if( getInteger() != PMD_MAGIC )
		return false;
	
	_iOffset -= 1;	//Magicword == 3bytes

	float fVersion = getFloat();
	if( fVersion != PMD_VERSION )
		return false;
	
	_iOffset += PMD_MODELNAME_SIZE;
	_iOffset += PMD_COMMENT_SIZE;
	
	return true;	
}
