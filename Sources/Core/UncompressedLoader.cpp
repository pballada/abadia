// UncompressedLoader.cpp
//
/////////////////////////////////////////////////////////////////////////////

#include <fstream>
#include "UncompressedLoader.h"
#include "system.h"

#ifdef ANDROID
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#endif
/////////////////////////////////////////////////////////////////////////////
// initialization and cleanup
/////////////////////////////////////////////////////////////////////////////

UncompressedLoader::UncompressedLoader()
{
}

UncompressedLoader::~UncompressedLoader()
{
}

/////////////////////////////////////////////////////////////////////////////
// data loading
/////////////////////////////////////////////////////////////////////////////

void UncompressedLoader::open(std::string path, std::string name)
{
	_path = path + "/" + name + "/";    
}

UINT8 *UncompressedLoader::load(std::string fileName, UINT32 fileSize, UINT32 CRC32)
{
    std::ifstream input(_path + fileName, std::ios::binary);
    if (!input) return nullptr;
    UINT8 *ptr = new UINT8[fileSize]{};
    if (!input.read(reinterpret_cast<char *>(ptr), fileSize)) {
        delete[] ptr;
        return nullptr;
    }

	return ptr;
}

void UncompressedLoader::dispose(UINT8 *ptr)
{
	delete[] ptr;
}

void UncompressedLoader::close()
{
	_path = "";
}
