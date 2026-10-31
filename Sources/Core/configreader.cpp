#include "configreader.h"

bool ConfigReader::parse()
{
    bool r = false;
    ifstream f(filename);
    std::string line;
    
    if (f.is_open())
    {
        r = true;
        while (getline(f, line))
        {
            if (!line.empty() && line[0] != '#')
            {
                // Remove spaces
                line.erase(remove(line.begin(), line.end(), ' '), line.end());                    
                
                // find the delimiter
                auto delimiterPosition = line.find('=');
                if (delimiterPosition == std::string::npos || delimiterPosition == 0) continue;
                
                // get token and value
                auto token = line.substr(0, delimiterPosition);
                auto value = line.substr(delimiterPosition+1,line.length());
                
                // store it                
                data.insert(make_pair(token, value));
                
            }
        }
    }
    else {
        std::cout << "Can't open:" << filename << std::endl;
    }    
    f.close();
    
    return r;
}

bool ConfigReader::isEmpty(){
    return data.empty();
}
