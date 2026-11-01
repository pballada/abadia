#pragma once
#include "BuscadorRutas.h"
#include "RejillaPantalla.h"
#include "PersonajeConIA.h"
#include "Sprite.h"
#include <cstring>
namespace Abadia {
// Recreates a legal route to the screen exit at local coordinate 22.
// The slope-to-flat movement advances two cells, crossing the central grid limit
// before every one-cell search waypoint has been consumed.
struct RouteBoundaryRegression {
    struct Walker : PersonajeConIA {
        explicit Walker(Sprite *sprite) : PersonajeConIA(sprite) {}
        void piensa() override {}
        using PersonajeConIA::leeComando;
    };
    static bool run() {
        auto *routes = elBuscadorDeRutas;
        auto *grid = routes->rejilla;
        grid->minPosX = grid->minPosY = grid->minAltura = 0;
        std::memset(grid->bufAlturas,1,sizeof(grid->bufAlturas));
        Sprite sprite;
        Walker walker(&sprite);
        walker.posX=20; walker.posY=12; walker.altura=1;
        walker.orientacion=0; walker.enDesnivel=true;
        walker.giradoEnDesnivel=false; walker.bajando=false;
        routes->posXIni=20; routes->posYIni=12;
        if (!routes->buscaEnPantalla(22,12)) return false;
        routes->grabaComandosCamino(&walker);
        // Planning must not move the live character, and must emit a bounded
        // movement prefix followed by the existing replan instruction.
        if (walker.posX!=20 || walker.posY!=12 || walker.altura!=1 || walker.orientacion!=0) return false;
        if (walker.posAcciones!=0 || walker.numBitAcciones!=0) return false;
        if (walker.leeComando()!=5) return false; // command to finish the slope
        walker.enDesnivel=false; // the movement decoder switches state here
        return walker.leeComando()==-1 && walker.pensarNuevoMovimiento;
    }
};
}
